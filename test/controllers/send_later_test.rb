require "test_helper"

# Annuler l'envoi (quelques secondes pour se raviser) et Envoyer plus tard.
class SendLaterTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @mailbox.grant!(users(:mohammad), "send")
    end
    sign_in_as users(:mohammad)
  end

  def new_message(**params)
    post drafts_path(account_id: @semisto.id), params: params.merge(draft: { kind: "new", mailbox_id: @mailbox.id,
      to_list: "anne@example.org", subject: "Planning", body: "Voici le planning." })
    with_account(@semisto) { Draft.last }
  end

  test "a sent message waits a few seconds, and can be cancelled meanwhile" do
    freeze_time do
      draft = nil
      assert_enqueued_with(job: SendDraftJob, at: Draft::UNDO_DELAY.from_now) { draft = new_message(send: "Envoyer") }
      assert_equal [ "scheduled", Draft::UNDO_DELAY.from_now ], draft.values_at(:status, :send_at)

      follow_redirect!
      assert_select ".toast p.notice", "Envoi depuis formations@semisto.org dans 10 s."
      assert_select ".toast[data-toast-delay-value] form[action='#{cancel_draft_path(draft, account_id: @semisto.id)}'] button", "Annuler"

      post cancel_draft_path(draft, account_id: @semisto.id)
      assert_redirected_to edit_draft_path(draft, account_id: @semisto.id)
      assert_equal "draft", with_account(@semisto) { draft.reload.status }

      # Le job prévu ne part plus.
      with_account(@semisto) { SendDraftJob.perform_now(draft) }
      assert_equal "draft", with_account(@semisto) { draft.reload.status }
    end
  end

  test "too late to cancel once the message is sent" do
    draft = with_account(@semisto) { Draft.create!(kind: "new", user: users(:mohammad), mailbox: @mailbox, to_list: "a@example.org", subject: "x", status: "sent") }
    post cancel_draft_path(draft, account_id: @semisto.id)
    follow_redirect!
    assert_select "p.alert", "Trop tard : le message est déjà parti."
  end

  test "send later at a chosen time, then change my mind" do
    travel_to Time.zone.local(2026, 10, 30, 21, 0) do
      get new_draft_path(account_id: @semisto.id)
      assert_select ".send-later button[name=send_later]", text: /Demain matin, 8h/
      assert_select ".send-later button[name=send_later]", text: /Ce soir/, count: 0 # trop tard pour ce soir

      monday = Time.zone.local(2026, 11, 2, 8, 0)
      draft = nil
      assert_enqueued_with(job: SendDraftJob, at: monday) { draft = new_message(send_later: monday.iso8601) }
      assert_redirected_to drafts_path(account_id: @semisto.id)
      follow_redirect!
      assert_select "p.notice", "Envoi prévu lundi 2 novembre à 8h00."
      assert_select "td", /Prévu/
      assert draft.send_later?

      # Le job ne part pas avant l'heure, même s'il est réveillé trop tôt.
      with_account(@semisto) { SendDraftJob.perform_now(draft) }
      assert_equal "scheduled", with_account(@semisto) { draft.reload.status }

      post cancel_draft_path(draft, account_id: @semisto.id)
      assert_equal "draft", with_account(@semisto) { draft.reload.status }
    end
  end

  test "a custom time must be in the future" do
    travel_to Time.zone.local(2026, 10, 30, 21, 0) do
      assert_no_enqueued_jobs(only: SendDraftJob) { new_message(send_later: "custom", send_at: "2026-10-29T08:00") }
      assert_response :unprocessable_entity
      assert_select ".errors, #error_explanation, .field-errors, .flash", /heure d'envoi à venir/

      assert_enqueued_with(job: SendDraftJob, at: Time.zone.local(2026, 10, 31, 9, 30)) do
        new_message(send_later: "custom", send_at: "2026-10-31T09:30")
      end
    end
  end
end
