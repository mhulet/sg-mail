require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @shared = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @shared.grant!(users(:michael), "manage")
      @shared.grant!(users(:mohammad), "send")
      @first = @shared.messages.create!(provider_uid: "a", thread_key: "t1", sent_at: 2.days.ago, subject: "Inscription", from_name: "Anne", labels: %w[INBOX], body_text: "Bonjour")
      @second = @shared.messages.create!(provider_uid: "b", thread_key: "t1", sent_at: 1.day.ago, subject: "Re: Inscription", from_name: "Mohammad", labels: %w[SENT])
      @archived = @shared.messages.create!(provider_uid: "c", thread_key: "t2", sent_at: 1.day.ago, subject: "Ancien", labels: [])
      Conversation.rebuild_for(@shared)
      @conversation = @first.reload.conversation
    end
  end

  def path(**params) = conversations_path(account_id: @semisto.id, **params)

  test "the unified inbox shows inbox threads, unread in bold" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get account_root_path(account_id: @semisto.id)
      assert_response :success
      assert_select "tr.unread a", "Inscription"
      assert_select "a", { text: "Ancien", count: 0 }

      get path(mailbox_id: @shared.id)
      assert_select "a", "Ancien"
    end
  end

  test "opening a thread marks it read for me only, and shows who read each message" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get conversation_path(@conversation, account_id: @semisto.id)
      assert_response :success
      assert_select "p.read-by", text: /Lu par Mohammad · pas encore par Michael/, count: 2

      get path
      assert_select "tr.unread", count: 0
    end

    sign_in_as users(:michael)
    get path
    assert_select "tr.unread a", "Inscription"
  end

  test "mark as unread, then unread filter" do
    sign_in_as users(:mohammad)
    get conversation_path(@conversation, account_id: @semisto.id)
    get path(unread: 1)
    assert_select "a", { text: "Inscription", count: 0 }

    post unread_conversation_path(@conversation, account_id: @semisto.id)
    get path(unread: 1)
    assert_select "tr.unread a", "Inscription"
  end

  test "mark everything as read" do
    sign_in_as users(:mohammad)
    post mark_all_read_conversations_path(account_id: @semisto.id)
    get path(mailbox_id: @shared.id)
    assert_select "tr.unread", count: 0
  end

  test "threads of a mailbox one cannot access stay hidden" do
    with_account(@semisto) { @shared.accesses.where(user: users(:mohammad)).delete_all }
    sign_in_as users(:mohammad)
    get path
    assert_select "a", { text: "Inscription", count: 0 }
    get conversation_path(@conversation, account_id: @semisto.id)
    assert_response :not_found
  end
end
