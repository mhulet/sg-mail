require "test_helper"

# Un utilisateur ne voit que les clients dont il est membre, et jamais les emails d'un autre client.
class AccountIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    @silvea = accounts(:silvea)
    with_account(@semisto) do
      @semisto_mailbox = Mailbox.create!(provider: "imap", address: "formations@semisto.org")
      @semisto_message = @semisto_mailbox.messages.create!(provider_uid: "1", subject: "Inscription formation")
      Conversation.rebuild_for(@semisto_mailbox)
      @semisto_conversation_id = @semisto_message.reload.conversation_id
      @semisto_mailbox.grant!(users(:michael), "manage")
      @semisto_mailbox.grant!(users(:mohammad), "send")
    end
    with_account(@silvea) do
      @silvea_mailbox = Mailbox.create!(provider: "imap", address: "contact@silvea.be")
      @silvea_message = @silvea_mailbox.messages.create!(provider_uid: "1", subject: "Devis confidentiel")
      Conversation.rebuild_for(@silvea_mailbox)
      @silvea_conversation_id = @silvea_message.reload.conversation_id
      @silvea_mailbox.grant!(users(:lea), "manage")
    end
  end

  test "a member reads their account's mailboxes and messages under row level security" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get mailboxes_path(account_id: @semisto.id)
      assert_response :success
      assert_select "a", "formations@semisto.org"
      assert_select "a", { text: "contact@silvea.be", count: 0 }

      get message_path(@semisto_message, account_id: @semisto.id)
      assert_redirected_to conversation_path(@semisto_conversation_id, account_id: @semisto.id, anchor: "message_#{@semisto_message.id}")
      follow_redirect!
      assert_select "h1", "Inscription formation"
    end
  end

  test "an account one is not a member of is out of reach" do
    sign_in_as users(:mohammad)
    get account_root_path(account_id: @silvea.id)
    assert_redirected_to accounts_path
  end

  test "another account's records cannot be reached through one's own account" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get message_path(@silvea_message, account_id: @semisto.id)
      assert_response :not_found
      get mailbox_path(@silvea_mailbox, account_id: @semisto.id)
      assert_response :not_found
      get conversation_path(@silvea_conversation_id, account_id: @semisto.id)
      assert_response :not_found
    end
  end

  test "only those who manage a mailbox disconnect it" do
    sign_in_as users(:mohammad)
    delete mailbox_path(@semisto_mailbox, account_id: @semisto.id)
    with_account(@semisto) { assert Mailbox.exists?(@semisto_mailbox.id) }

    sign_in_as users(:michael)
    delete mailbox_path(@semisto_mailbox, account_id: @semisto.id)
    with_account(@semisto) { assert_not Mailbox.exists?(@semisto_mailbox.id) }
  end

  test "syncing a mailbox queues a job for its account" do
    sign_in_as users(:mohammad)
    assert_enqueued_with(job: SyncMailboxJob, args: [ @semisto_mailbox ]) do
      post sync_mailbox_path(@semisto_mailbox, account_id: @semisto.id)
    end
  end
end
