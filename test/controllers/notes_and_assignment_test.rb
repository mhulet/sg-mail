require "test_helper"

class NotesAndAssignmentTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @mailbox.grant!(users(:michael), "send")
      @mailbox.grant!(users(:mohammad), "send")
      @message = @mailbox.messages.create!(provider_uid: "a", thread_key: "t1", subject: "Inscription",
        from_address: "anne@example.org", sent_at: 1.day.ago, body_text: "Bonjour", labels: %w[INBOX])
      Conversation.rebuild_for(@mailbox)
      @conversation = @message.reload.conversation
    end
  end

  test "assign a thread and filter the inbox on it" do
    sign_in_as users(:michael)
    patch assign_conversation_path(@conversation, account_id: @semisto.id), params: { assignee_id: users(:mohammad).id }
    assert_equal users(:mohammad).id, with_account(@semisto) { @conversation.reload.assignee_id }

    sign_in_as users(:mohammad)
    get conversations_path(account_id: @semisto.id, mine: 1)
    assert_select "table.conversations tr", 1

    sign_in_as users(:michael)
    get conversations_path(account_id: @semisto.id, mine: 1)
    assert_select "table.conversations tr", 0
  end

  test "internal notes: visible to the team, deletable by their author only" do
    sign_in_as users(:michael)
    post conversation_notes_path(@conversation, account_id: @semisto.id), params: { note: { body: "Elle a déjà payé." } }
    note = with_account(@semisto) { Note.sole }

    sign_in_as users(:mohammad)
    get conversation_path(@conversation, account_id: @semisto.id)
    assert_select "#note_#{note.id}", text: /Elle a déjà payé/
    delete conversation_note_path(@conversation, note, account_id: @semisto.id)
    assert_response :not_found
    assert with_account(@semisto) { Note.exists?(note.id) }
  end
end
