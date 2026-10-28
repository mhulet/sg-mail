require "test_helper"

class StacksTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @shared = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @shared.grant!(users(:michael), "manage")
      @shared.grant!(users(:mohammad), "send")
      @shared.messages.create!(provider_uid: "a", thread_key: "t1", from_address: "anne@example.org", from_name: "Anne",
        subject: "Inscription", sent_at: 2.days.ago, labels: %w[INBOX])
      @shared.messages.create!(provider_uid: "b", thread_key: "t2", from_address: "paul@example.org", from_name: "Paul",
        subject: "Facture", sent_at: 1.day.ago, labels: %w[INBOX])
      Conversation.rebuild_for(@shared)
      @inscription = Conversation.find_by!(thread_key: "t1")
    end
  end

  test "reply later and set aside take a thread out of my inbox, for me only" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get conversation_path(@inscription, account_id: @semisto.id)
      assert_select ".actions button", "Répondre plus tard"

      patch stack_conversation_path(@inscription, account_id: @semisto.id), params: { stack: "reply_later", on: "1" }
      follow_redirect!
      assert_select "p.notice", "Fil ajouté à « Répondre plus tard »."
      assert_select ".actions button", "Retirer de « Répondre plus tard »"

      get account_root_path(account_id: @semisto.id)
      assert_select "table a", { text: "Inscription", count: 0 }
      assert_select "p.stacks a", "Répondre plus tard (1)"

      get conversations_path(account_id: @semisto.id, stack: "reply_later")
      assert_select "h1", "Répondre plus tard"
      assert_select "table a", "Inscription"
      assert_select "table a", { text: "Facture", count: 0 }

      patch stack_conversation_path(@inscription, account_id: @semisto.id), params: { stack: "set_aside", on: "1" }
      get conversations_path(account_id: @semisto.id, stack: "set_aside")
      assert_select "table a", "Inscription"

      patch stack_conversation_path(@inscription, account_id: @semisto.id), params: { stack: "reply_later", on: "0" }
      patch stack_conversation_path(@inscription, account_id: @semisto.id), params: { stack: "set_aside", on: "0" }
      get account_root_path(account_id: @semisto.id)
      assert_select "table a", "Inscription"
      assert_select "p.stacks", count: 0
    end

    sign_in_as users(:michael)
    patch stack_conversation_path(@inscription, account_id: @semisto.id), params: { stack: "set_aside", on: "1" }
    sign_in_as users(:mohammad)
    get account_root_path(account_id: @semisto.id)
    assert_select "table a", "Inscription"
  end

  test "an unknown stack is refused" do
    sign_in_as users(:michael)
    patch stack_conversation_path(@inscription, account_id: @semisto.id), params: { stack: "someday", on: "1" }
    follow_redirect!
    assert_select "p.alert", "Pile inconnue."
  end
end
