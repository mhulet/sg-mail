require "test_helper"

# Un même email envoyé à deux boîtes du client (communication@ et michael@) : un fil par boîte, un seul
# dans la réception unifiée et la recherche.
class DuplicateEmailsTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @team = Mailbox.create!(provider: "imap", address: "communication@les4sources.be")
      @personal = Mailbox.create!(provider: "imap", address: "michael@les4sources.be")
      @team.grant!(users(:michael), "manage")
      @team.grant!(users(:mohammad), "send")
      @personal.grant!(users(:michael), "manage")
      [ @team, @personal ].each do |mailbox|
        folder = mailbox.mail_folders.create!(name: "INBOX")
        mailbox.messages.create!(provider_uid: "INBOX/1/7", thread_key: "<anes@example.org>", message_id_header: "anes@example.org",
          mail_folder: folder, sent_at: 1.hour.ago, subject: "Ânes 4 sources", from_name: "Olivier", body_text: "Voici les photos")
        mailbox.messages.create!(provider_uid: "INBOX/1/8", thread_key: "<other-#{mailbox.id}@example.org>",
          message_id_header: "other-#{mailbox.id}@example.org", mail_folder: folder, sent_at: 2.hours.ago, subject: "Autre #{mailbox.address}")
        Conversation.rebuild_for(mailbox)
      end
      @team_copy = @team.conversations.find_by!(root_message_id: "anes@example.org")
      @personal_copy = @personal.conversations.find_by!(root_message_id: "anes@example.org")
    end
  end

  def path(**params) = conversations_path(account_id: @semisto.id, **params)

  test "the unified inbox shows the email once, with every mailbox it landed in" do
    sign_in_as users(:michael)
    with_restricted_database_role do
      get path
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }
      assert_select "tr", text: /Ânes 4 sources/ do
        assert_select ".mailbox-chip", 2
        assert_select ".mailbox-chip", "communication@les4sources.be"
        assert_select ".mailbox-chip", "michael@les4sources.be"
      end
      assert_select "table a", "Autre communication@les4sources.be"
      assert_select "table a", "Autre michael@les4sources.be"

      get path(mailbox_id: @team.id)
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }
      get path(mailbox_id: @personal.id)
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }
    end
  end

  test "someone who sees only one mailbox sees only that copy" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get path
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }
      get conversation_path(@team_copy, account_id: @semisto.id)
      assert_select ".twins", count: 0
    end
  end

  test "reading one copy reads the other, and the thread links to it" do
    sign_in_as users(:michael)
    with_restricted_database_role do
      get conversation_path(@team_copy, account_id: @semisto.id)
      assert_select ".twins a[href=?]", conversation_path(@personal_copy, account_id: @semisto.id)

      get path
      assert_select "tr.unread", text: /Ânes 4 sources/, count: 0
      get path(mailbox_id: @personal.id)
      assert_select "tr.unread", text: /Ânes 4 sources/, count: 0

      post unread_conversation_path(@personal_copy, account_id: @semisto.id)
      get path(mailbox_id: @team.id)
      assert_select "tr.unread", text: /Ânes 4 sources/, count: 1
    end
  end

  test "archiving or stacking the email applies to every copy, for me only" do
    sign_in_as users(:michael)
    with_restricted_database_role do
      patch stack_conversation_path(@team_copy, account_id: @semisto.id), params: { stack: "reply_later", on: "1" }
      get path
      assert_select "table a", { text: "Ânes 4 sources", count: 0 }
      assert_select "p.stacks a", "Répondre plus tard (1)"
      get path(stack: "reply_later")
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }

      patch archive_conversation_path(@personal_copy, account_id: @semisto.id), params: { on: "1" }
      get path(mailbox_id: @team.id)
      assert_select "table a", { text: "Ânes 4 sources", count: 0 }
      get path(archived: 1)
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }
    end

    sign_in_as users(:mohammad)
    get path
    assert_select "table a", "Ânes 4 sources"
  end

  test "search finds the email once" do
    sign_in_as users(:michael)
    with_restricted_database_role do
      get search_path(account_id: @semisto.id, q: "photos")
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }
      get search_path(account_id: @semisto.id, q: "photos", mailbox_id: @personal.id)
      assert_select "table a", { text: "Ânes 4 sources", count: 1 }
    end
  end

  test "the API lists the email once and names the other copy" do
    token = ApiToken.create!(user: users(:michael), account: @semisto, name: "CLI").token
    get api_v1_conversations_path, headers: { "Authorization" => "Bearer #{token}" }
    anes = response.parsed_body["conversations"].select { |c| c["subject"] == "Ânes 4 sources" }
    assert_equal 1, anes.size
    assert_equal 1, anes.first["also_in"].size
  end
end
