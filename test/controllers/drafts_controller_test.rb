require "test_helper"

class DraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @mailbox.grant!(users(:mohammad), "send")
      @mailbox.grant!(users(:michael), "read")
      @message = @mailbox.messages.create!(provider_uid: "a", thread_key: "t1", subject: "Inscription",
        from_address: "anne@example.org", sent_at: 1.day.ago, body_text: "Bonjour", labels: %w[INBOX])
      Conversation.rebuild_for(@mailbox)
    end
  end

  test "reply from a thread, save as draft, then send" do
    sign_in_as users(:mohammad)
    get new_draft_path(account_id: @semisto.id, message_id: @message.id, kind: "reply")
    assert_response :success
    assert_select "input[name='draft[to_list]'][value='anne@example.org']"

    post drafts_path(account_id: @semisto.id), params: { draft: { kind: "reply", source_message_id: @message.id, mailbox_id: @mailbox.id,
      to_list: "anne@example.org", subject: "Re: Inscription", body: "C'est noté." } }
    draft = with_account(@semisto) { Draft.last }
    assert_redirected_to edit_draft_path(draft, account_id: @semisto.id)
    assert_equal [ "draft", @message.id ], [ draft.status, draft.source_message_id ]

    assert_enqueued_with(job: SendDraftJob) do
      patch draft_path(draft, account_id: @semisto.id), params: { send: "Envoyer", draft: { body: "C'est noté, merci." } }
    end
    assert_equal "sending", with_account(@semisto) { draft.reload.status }
  end

  test "my signature and sender name for a mailbox" do
    sign_in_as users(:mohammad)
    patch preferences_mailbox_path(@mailbox, account_id: @semisto.id),
      params: { mailbox_access: { sender_name: "Semisto Academy", signature: "Mohammad\nSemisto Academy" } }
    assert_redirected_to mailbox_path(@mailbox, account_id: @semisto.id)

    get new_draft_path(account_id: @semisto.id)
    assert_match(/\A\n*-- \nMohammad\nSemisto Academy\z/, css_select("textarea[name='draft[body]']").text)

    get new_draft_path(account_id: @semisto.id, message_id: @message.id, kind: "reply")
    body = css_select("textarea[name='draft[body]']").text
    assert_match(/\A\n*-- \nMohammad\nSemisto Academy\n\nLe .*a écrit :\n> Bonjour\z/, body)

    draft = with_account(@semisto) { Draft.start(user: users(:mohammad), mailbox: @mailbox, body: "Bonjour") }
    assert_equal "Bonjour\n\n-- \nMohammad\nSemisto Academy", draft.body
    draft.assign_attributes(to_list: "anne@example.org", subject: "x")
    assert_equal "Semisto Academy <formations@semisto.org>", with_account(@semisto) { MailSender.new(draft).mail[:from].value }

    # Les préférences d'une personne ne changent pas celles des autres.
    assert_nil with_account(@semisto) { @mailbox.access_for(users(:michael)).signature }
  end

  test "a reader cannot send from the mailbox" do
    sign_in_as users(:michael)
    get new_draft_path(account_id: @semisto.id)
    assert_redirected_to account_root_path(account_id: @semisto.id)

    assert_no_difference -> { with_account(@semisto) { Draft.count } } do
      post drafts_path(account_id: @semisto.id), params: { send: "Envoyer", draft: { kind: "new", mailbox_id: @mailbox.id, to_list: "x@example.org", subject: "x", body: "x" } }
    end
  end

  test "drafts are private to their author" do
    draft = with_account(@semisto) { Draft.create!(kind: "new", user: users(:mohammad), mailbox: @mailbox, subject: "Secret") }
    sign_in_as users(:michael)
    get edit_draft_path(draft, account_id: @semisto.id)
    assert_response :not_found
  end

  test "the send job marks the draft sent, or failed with the reason" do
    draft = with_account(@semisto) { Draft.create!(kind: "new", user: users(:mohammad), mailbox: @mailbox, to_list: "a@example.org", subject: "x", status: "sending") }
    MailSender.class_eval { alias_method :original_deliver, :deliver; def deliver = raise(MailSender::Error, "SMTP refusé") }
    with_account(@semisto) { SendDraftJob.perform_now(draft) }
    assert_equal [ "failed", "MailSender::Error: SMTP refusé" ], with_account(@semisto) { draft.reload.values_at(:status, :error) }

    MailSender.class_eval { def deliver = true }
    with_account(@semisto) do
      conversation = @message.reload.conversation
      ConversationState.put!(conversation, users(:mohammad), "reply_later")
      ConversationState.put!(conversation, users(:michael), "reply_later")
      draft.update!(status: "sending", conversation: conversation)
      assert_enqueued_with(job: SyncMailboxJob) { SendDraftJob.perform_now(draft) }
      assert_equal "sent", draft.reload.status
      # Répondre sort le fil de « Répondre plus tard » pour qui a répondu, pas pour les autres.
      assert_equal [ [], [ "reply_later" ] ], [ conversation.reload.stacks_for(users(:mohammad)), conversation.stacks_for(users(:michael)) ]
    end
  ensure
    MailSender.class_eval { alias_method :deliver, :original_deliver }
  end
end
