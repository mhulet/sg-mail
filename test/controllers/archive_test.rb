require "test_helper"

class ArchiveTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  class FakeGmail
    attr_reader :calls
    def modify_thread(user_id, thread_id, request) = (@calls ||= []) << [ user_id, thread_id, request.add_label_ids, request.remove_label_ids ]
  end

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

  test "archiving takes a thread out of my inbox until a new message arrives, for me only" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get conversation_path(@inscription, account_id: @semisto.id)
      patch stack_conversation_path(@inscription, account_id: @semisto.id), params: { stack: "reply_later", on: "1" }
      patch archive_conversation_path(@inscription, account_id: @semisto.id), params: { on: "1" }
      follow_redirect!
      assert_select "p.notice", "Fil archivé : il reviendra au prochain message."
      assert_select "table a", { text: "Inscription", count: 0 }
      assert_select "table a", "Facture"
      assert_select "p.stacks", count: 0 # archiver sort aussi de « Répondre plus tard »

      get conversations_path(account_id: @semisto.id, archived: 1)
      assert_select "h1", "Archivés"
      assert_select "table a", "Inscription"
      assert_select "table a", { text: "Facture", count: 0 }

      get conversation_path(@inscription, account_id: @semisto.id)
      assert_select ".actions button", "Remettre dans la réception"
    end

    sign_in_as users(:michael)
    get account_root_path(account_id: @semisto.id)
    assert_select "table a", "Inscription"

    with_account(@semisto) do
      @shared.messages.create!(provider_uid: "c", thread_key: "t1", from_address: "anne@example.org", subject: "Re: Inscription",
        sent_at: 1.minute.from_now, labels: %w[INBOX])
      Conversation.rebuild_for(@shared)
    end
    sign_in_as users(:mohammad)
    get account_root_path(account_id: @semisto.id)
    assert_select "table a", "Inscription"
  end

  test "the thread leaves the Gmail inbox once everyone archived it, and comes back when unarchived" do
    gmail = FakeGmail.new
    originals = %i[for_mailbox gmail_service].index_with { |name| GoogleOauth.method(name) }
    GoogleOauth.define_singleton_method(:for_mailbox) { |_mailbox| nil }
    GoogleOauth.define_singleton_method(:gmail_service) { |_authorization| gmail }

    sign_in_as users(:mohammad)
    perform_enqueued_jobs { patch archive_conversation_path(@inscription, account_id: @semisto.id), params: { on: "1" } }
    assert_nil gmail.calls # Michael ne l'a pas encore archivé

    sign_in_as users(:michael)
    perform_enqueued_jobs { patch archive_conversation_path(@inscription, account_id: @semisto.id), params: { on: "1" } }
    assert_equal [ [ "me", "t1", [], [ "INBOX" ] ] ], gmail.calls
    with_account(@semisto) do
      assert_not @inscription.reload.in_inbox
      assert_equal [], @inscription.messages.first.labels
    end

    perform_enqueued_jobs { patch archive_conversation_path(@inscription, account_id: @semisto.id), params: { on: "0" } }
    assert_equal [ "me", "t1", [ "INBOX" ], [] ], gmail.calls.last
    with_account(@semisto) { assert @inscription.reload.in_inbox }
    get account_root_path(account_id: @semisto.id)
    assert_select "table a", "Inscription"
  ensure
    originals.each { |name, method| GoogleOauth.define_singleton_method(name, method) }
  end

  test "archive through the API" do
    token = ApiToken.create!(user: users(:mohammad), account: @semisto, name: "CLI").token
    headers = { "Authorization" => "Bearer #{token}" }
    patch api_v1_conversation_path(@inscription), params: { archived: true }, headers: headers
    assert response.parsed_body.dig("conversation", "archived")

    get api_v1_conversations_path, headers: headers
    assert_equal [ "Facture" ], response.parsed_body["conversations"].map { |c| c["subject"] }
    get api_v1_conversations_path(archived: 1), headers: headers
    assert_equal [ "Inscription" ], response.parsed_body["conversations"].map { |c| c["subject"] }

    patch api_v1_conversation_path(@inscription), params: { archived: false }, headers: headers
    assert_not response.parsed_body.dig("conversation", "archived")
  end
end
