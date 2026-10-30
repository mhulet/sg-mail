require "test_helper"

class FlourishesTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "imap", address: "michael@les4sources.be")
      @mailbox.grant!(users(:michael), "manage")
      %w[Inscription Facture Visite Devis].each_with_index do |subject, i|
        @mailbox.messages.create!(provider_uid: subject, thread_key: "t#{i}", from_address: "anne@example.org",
          subject: subject, sent_at: i.hours.ago, labels: %w[INBOX])
      end
      Conversation.rebuild_for(@mailbox)
      @conversations = Conversation.order(:id).to_a
    end
    sign_in_as users(:michael)
  end

  test "archiving a thread drops one letter into the box, once" do
    patch archive_conversation_path(@conversations.first, account_id: @semisto.id), params: { on: "1" }
    follow_redirect!
    assert_select ".flourish[data-kind=archive][aria-hidden=true] .letter", count: 1
    get conversations_path(account_id: @semisto.id)
    assert_select ".flourish", count: 0
  end

  test "archiving several threads drops up to three letters, and undo pulls one back out" do
    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "archive", ids: @conversations.map(&:id) }
    follow_redirect!
    assert_select ".flourish[data-kind=archive] .letter", count: 3

    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "unarchive", ids: [ @conversations.first.id ] }
    follow_redirect!
    assert_select ".flourish[data-kind=unarchive] .letter", count: 1
  end

  test "reply later rings a clock, set aside lands on a pile, marking as read stays quiet" do
    patch stack_conversation_path(@conversations.first, account_id: @semisto.id), params: { stack: "reply_later", on: "1" }
    follow_redirect!
    assert_select ".flourish[data-kind=reply_later] .clock"

    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "set_aside", ids: [ @conversations.second.id ] }
    follow_redirect!
    assert_select ".flourish[data-kind=set_aside] .pile"

    patch stack_conversation_path(@conversations.first, account_id: @semisto.id), params: { stack: "reply_later", on: "0" }
    follow_redirect!
    assert_select ".flourish", count: 0
    post bulk_conversations_path(account_id: @semisto.id), params: { operation: "read", ids: [ @conversations.third.id ] }
    follow_redirect!
    assert_select ".flourish", count: 0
  end
end
