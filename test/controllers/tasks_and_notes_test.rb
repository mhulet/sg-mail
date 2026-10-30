require "test_helper"

class TasksAndNotesTest < ActionDispatch::IntegrationTest
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

  test "create a task from a message, assign it, complete it" do
    sign_in_as users(:michael)
    post tasks_path(account_id: @semisto.id), params: { task: { message_id: @message.id, title: "Envoyer le programme",
      assignee_id: users(:mohammad).id, due_on: Date.current + 2 } }
    task = with_account(@semisto) { Task.sole }
    assert_equal [ @conversation.id, users(:mohammad).id, users(:michael).id ], [ task.conversation_id, task.assignee_id, task.creator_id ]

    sign_in_as users(:mohammad)
    get tasks_path(account_id: @semisto.id)
    assert_select "li#task_#{task.id}", text: /Envoyer le programme/
    get conversation_path(@conversation, account_id: @semisto.id)
    assert_select "section.internal li#task_#{task.id}"

    patch task_path(task, account_id: @semisto.id, status: "done")
    assert with_account(@semisto) { task.reload.done? }
    get tasks_path(account_id: @semisto.id)
    assert_select "li.done.just-done#task_#{task.id}" # barrée sous nos yeux, une fois
    get tasks_path(account_id: @semisto.id)
    assert_select "li.just-done", count: 0
  end

  test "a task cannot be given to someone outside the client" do
    sign_in_as users(:michael)
    assert_no_difference -> { with_account(@semisto) { Task.count } } do
      post tasks_path(account_id: @semisto.id), params: { task: { title: "x", assignee_id: users(:lea).id } }
    end
  end

  test "tasks of a thread stay hidden from people without access to the mailbox" do
    task = with_account(@semisto) { Task.create!(title: "Secret", creator: users(:michael), conversation: @conversation) }
    with_account(@semisto) { @mailbox.accesses.find_by(user: users(:mohammad)).destroy! }
    sign_in_as users(:mohammad)
    patch task_path(task, account_id: @semisto.id, status: "done")
    assert_response :not_found
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
