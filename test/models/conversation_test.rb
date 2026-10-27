require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = accounts(:semisto)
    @gmail = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
    @imap = Mailbox.create!(provider: "imap", address: "michael@semisto.org")
    @inbox = @imap.mail_folders.create!(name: "INBOX")
    @sent = @imap.mail_folders.create!(name: "Sent")
  end

  def create_message(mailbox, uid, thread_key:, sent_at:, **attributes)
    mailbox.messages.create!(provider_uid: uid, thread_key: thread_key, sent_at: sent_at, **attributes)
  end

  test "groups messages into threads, with the latest sender and the first subject" do
    create_message(@gmail, "a", thread_key: "t1", sent_at: 2.days.ago, subject: "Formation", from_name: "Anne", labels: %w[INBOX])
    create_message(@gmail, "b", thread_key: "t1", sent_at: 1.day.ago, subject: "Re: Formation", from_name: "Mohammad", labels: %w[SENT])
    create_message(@gmail, "c", thread_key: "t2", sent_at: 3.days.ago, subject: "Facture", labels: %w[SENT])

    Conversation.rebuild_for(@gmail)

    formation, facture = @gmail.conversations.recent.to_a
    assert_equal [ "Formation", "Mohammad", 2, true ], formation.values_at(:subject, :last_sender, :messages_count, :in_inbox)
    assert_equal [ "Facture", false ], facture.values_at(:subject, :in_inbox)
    assert_equal [ formation.id ] * 2, @gmail.messages.where(thread_key: "t1").pluck(:conversation_id)
  end

  test "an IMAP thread spans the inbox and the sent folder" do
    create_message(@imap, "INBOX/1/1", thread_key: "<x@a>", sent_at: 2.days.ago, mail_folder: @inbox)
    create_message(@imap, "Sent/1/1", thread_key: "<x@a>", sent_at: 1.day.ago, mail_folder: @sent)

    Conversation.rebuild_for(@imap)

    assert_equal [ [ 2, true ] ], @imap.conversations.pluck(:messages_count, :in_inbox)
  end

  test "keeps up with new and deleted messages" do
    first = create_message(@gmail, "a", thread_key: "t1", sent_at: 2.days.ago, labels: %w[INBOX])
    Conversation.rebuild_for(@gmail)
    conversation = @gmail.conversations.sole

    create_message(@gmail, "b", thread_key: "t1", sent_at: 1.hour.ago, from_name: "Léa")
    Conversation.rebuild_for(@gmail)
    assert_equal [ 2, "Léa" ], conversation.reload.values_at(:messages_count, :last_sender)

    @gmail.messages.delete_all
    Conversation.rebuild_for(@gmail)
    assert_not Conversation.exists?(conversation.id)
    assert first
  end

  test "a message without thread key gets its own thread" do
    create_message(@gmail, "a", thread_key: nil, sent_at: 1.day.ago)
    create_message(@gmail, "b", thread_key: nil, sent_at: 1.day.ago)
    Conversation.rebuild_for(@gmail)
    assert_equal 2, @gmail.conversations.count
  end

  test "readings are per person" do
    create_message(@gmail, "a", thread_key: "t1", sent_at: 1.day.ago, labels: %w[INBOX])
    create_message(@gmail, "b", thread_key: "t1", sent_at: 1.hour.ago, labels: %w[INBOX])
    Conversation.rebuild_for(@gmail)
    conversation = @gmail.conversations.sole
    unread = ->(user) { Conversation.with_unread_for(user).find(conversation.id).unread }

    assert unread.(users(:michael))
    conversation.mark_read_by!(users(:michael))
    conversation.mark_read_by!(users(:michael)) # sans doublon
    assert_not unread.(users(:michael))
    assert unread.(users(:mohammad))
    assert_equal 2, Reading.where(user: users(:michael)).count

    conversation.mark_unread_by!(users(:michael))
    assert unread.(users(:michael))
    assert_equal 1, Reading.where(user: users(:michael)).count
  end
end
