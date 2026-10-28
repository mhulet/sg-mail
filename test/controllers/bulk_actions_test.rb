require "test_helper"

class BulkActionsTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @shared = Mailbox.create!(provider: "imap", address: "formations@semisto.org")
      @shared.grant!(users(:michael), "manage")
      @shared.grant!(users(:mohammad), "send")
      %w[Inscription Facture Visite].each_with_index do |subject, i|
        @shared.messages.create!(provider_uid: "m#{i}", thread_key: "t#{i}", from_address: "anne@example.org", subject: subject,
          sent_at: (i + 1).hours.ago, labels: %w[INBOX])
      end
      Conversation.rebuild_for(@shared)
      @ids = Conversation.order(:thread_key).pluck(:id)
    end
    sign_in_as users(:mohammad)
  end

  test "undo an archive from the confirmation" do
    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "archive", ids: @ids.first(2) },
      headers: { "Referer" => account_root_url(account_id: @semisto.id) }
    follow_redirect!
    assert_select ".toast button.undo[data-shortcut=z]", "Annuler"
    assert_select ".toast input[name='ids[]']", 2

    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "unarchive", ids: @ids.first(2) },
      headers: { "Referer" => account_root_url(account_id: @semisto.id) }
    follow_redirect!
    assert_select "table a", "Inscription"
    assert_select ".toast button.undo", count: 0
  end

  test "archive, mark read and stack several threads at once, for me only" do
    get account_root_path(account_id: @semisto.id)
    assert_select "form#bulk button", "Archiver"
    assert_select "input[type=checkbox][form=bulk]", 3

    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "archive", ids: @ids.first(2) },
      headers: { "Referer" => account_root_url(account_id: @semisto.id) }
    follow_redirect!
    assert_select "p.notice", "2 fils archivés."
    assert_select "table a", "Visite"
    assert_select "table a", { text: "Inscription", count: 0 }

    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "read", ids: [ @ids.last ] }
    assert_equal "1 fil marqué comme lu.", flash[:notice]
    get account_root_path(account_id: @semisto.id, unread: 1)
    assert_select "table a", { text: "Visite", count: 0 }

    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "reply_later", ids: [ @ids.last ] }
    get conversations_path(account_id: @semisto.id, stack: "reply_later")
    assert_select "table a", "Visite"

    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "unarchive", ids: @ids.first(2) }
    assert_equal "2 fils remis dans la réception.", flash[:notice]

    sign_in_as users(:michael)
    get account_root_path(account_id: @semisto.id)
    assert_select "table a", 3
  end

  test "nothing checked, an unknown action or someone else's threads do nothing" do
    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "archive" }
    assert_equal "Coche au moins un fil.", flash[:alert]
    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "delete", ids: @ids }
    assert_equal "Coche au moins un fil.", flash[:alert]

    other = with_account(@semisto) do
      private_box = Mailbox.create!(provider: "imap", address: "michael@semisto.org")
      private_box.grant!(users(:michael), "manage")
      private_box.messages.create!(provider_uid: "p", thread_key: "p", from_address: "x@example.org", subject: "Privé", sent_at: 1.hour.ago, labels: %w[INBOX])
      Conversation.rebuild_for(private_box)
      Conversation.find_by!(thread_key: "p")
    end
    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "archive", ids: [ other.id ] }
    assert_equal "Coche au moins un fil.", flash[:alert]
  end

  test "the keyboard shortcuts help is on every page" do
    get account_root_path(account_id: @semisto.id)
    assert_select "dialog.shortcuts dt", "j / k"
    assert_select "a[data-shortcut='g i']", "Réception"
  end
end
