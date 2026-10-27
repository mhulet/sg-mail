require "test_helper"

class Api::V1Test < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @mailbox.grant!(users(:mohammad), "send")
      @mailbox.grant!(users(:michael), "read")
      @message = @mailbox.messages.create!(provider_uid: "a", thread_key: "t1", subject: "Inscription",
        from_address: "anne@example.org", sent_at: 1.day.ago, body_html: "<p>Bonjour, je m'inscris.</p>", labels: %w[INBOX])
      Conversation.rebuild_for(@mailbox)
      @conversation_id = @message.reload.conversation_id
    end
    @token = ApiToken.create!(user: users(:mohammad), account: @semisto, name: "CLI").token
  end

  test "rejects missing, unknown and orphaned tokens" do
    get api_v1_me_path
    assert_response :unauthorized
    get api_v1_me_path, headers: auth("sgm_nope")
    assert_response :unauthorized

    lea_token = ApiToken.create!(user: users(:lea), account: @semisto, name: "x").token # Léa n'est pas membre de Semisto
    get api_v1_me_path, headers: auth(lea_token)
    assert_response :unauthorized
  end

  test "me, inbox, search and thread detail" do
    get api_v1_me_path, headers: auth
    assert_equal [ "Mohammad", "Semisto", [ "formations@semisto.org" ] ],
      [ json["user"]["name"], json["account"]["name"], json["mailboxes"].map { |m| m["address"] } ]

    get api_v1_conversations_path(unread: 1), headers: auth
    assert_equal [ @conversation_id ], json["conversations"].map { |c| c["id"] }
    assert json["conversations"].first["unread"]

    get api_v1_conversations_path(q: "inscri"), headers: auth
    assert_equal 1, json["conversations"].size

    get api_v1_conversation_path(@conversation_id, mark_read: 1), headers: auth
    message = json["conversation"]["messages"].sole
    assert_equal "Bonjour, je m'inscris.", message["body"].strip
    assert_equal [ "Mohammad" ], message["read_by"]
    assert_not ApiToken.find_by(name: "CLI").last_used_at.nil?
  end

  test "assign, note, task, then draft a reply and send it" do
    patch api_v1_conversation_path(@conversation_id), params: { assignee_id: users(:mohammad).id }, headers: auth
    assert_equal "Mohammad", json["conversation"]["assignee"]["name"]

    post api_v1_conversation_notes_path(@conversation_id), params: { body: "Déjà payé" }, headers: auth
    assert_response :created

    post api_v1_tasks_path, params: { title: "Envoyer le programme", message_id: @message.id, due_on: "2026-11-02" }, headers: auth
    assert_response :created
    task_id = json["task"]["id"]
    assert_equal [ @conversation_id, "Mohammad" ], [ json["task"]["conversation_id"], json["task"]["assignee"]["name"] ]
    patch api_v1_task_path(task_id), params: { status: "done" }, headers: auth
    assert_equal "done", json["task"]["status"]

    post api_v1_drafts_path, params: { message_id: @message.id, body: "Bien reçu !" }, headers: auth
    assert_response :created
    draft = json["draft"]
    assert_equal [ [ "anne@example.org" ], "Re: Inscription" ], draft.values_at("to", "subject")
    assert draft["body"].start_with?("Bien reçu !\n\nLe ")

    post deliver_api_v1_draft_path(draft["id"]), headers: auth
    assert_response :accepted
    assert_equal "SendDraftJob", enqueued_jobs.sole["job_class"]
  end

  test "a reader cannot draft from the mailbox, nor see other people's drafts" do
    token = ApiToken.create!(user: users(:michael), account: @semisto, name: "x").token
    post api_v1_drafts_path, params: { message_id: @message.id, body: "x" }, headers: auth(token)
    assert_response :unprocessable_entity

    get api_v1_conversation_path(@conversation_id + 1000), headers: auth(token)
    assert_response :not_found
  end

  test "tokens are created and revoked from the web interface, shown once" do
    sign_in_as users(:mohammad)
    post api_tokens_path(account_id: @semisto.id), params: { api_token: { name: "MacBook" } }
    token = response.body[/sgm_[\w-]+/]
    get api_v1_me_path, headers: auth(token)
    assert_response :success

    get api_tokens_path(account_id: @semisto.id)
    assert_not_includes response.body, token
    delete api_token_path(ApiToken.find_by(name: "MacBook"), account_id: @semisto.id)
    get api_v1_me_path, headers: auth(token)
    assert_response :unauthorized
  end

  private

  def auth(token = @token) = { "Authorization" => "Bearer #{token}" }
  def json = response.parsed_body
end
