require "test_helper"

# Un connecteur Claude qui couvre tous les clients de la personne.
class McpAllAccountsTest < ActionDispatch::IntegrationTest
  REDIRECT_URI = "https://claude.ai/api/mcp/auth_callback".freeze

  setup do
    @semisto, @silvea = accounts(:semisto), accounts(:silvea)
    @michael = users(:michael)
    Membership.create!(account: @silvea, user: @michael, role: "member")
    @semisto_message = create_message(@semisto, "formations@semisto.org", "Inscription formation", 2.days.ago)
    @silvea_message = create_message(@silvea, "contact@silvea.be", "Commande de plants", 1.day.ago)
  end

  test "the consent screen offers every client, and that is the default" do
    sign_in_as @michael
    get oauth_authorization_path(authorization_params(register_client, "verifier"))
    assert_select "select[name=sg_account_id] option[value='']", /Tous mes clients/
  end

  test "one connection reads and writes in every client, and says where each item comes from" do
    @token = authorize_and_get_tokens["access_token"]

    call_tool("whoami")
    assert_equal [ [ "Semisto", [ "formations@semisto.org" ] ], [ "Silvéa", [ "contact@silvea.be" ] ] ],
      structured["accounts"].map { |account| [ account["name"], account["mailboxes"].map { |m| m["address"] } ] }

    call_tool("search_conversations")
    assert_equal [ [ "Commande de plants", "Silvéa" ], [ "Inscription formation", "Semisto" ] ],
      structured["conversations"].map { |c| [ c["subject"], c.dig("account", "name") ] }

    call_tool("search_conversations", account_id: @semisto.id)
    assert_equal [ "Inscription formation" ], structured["conversations"].map { |c| c["subject"] }

    call_tool("search_conversations", query: "plants")
    assert_equal [ "Silvéa" ], structured["conversations"].map { |c| c.dig("account", "name") }

    silvea_conversation = with_account(@silvea) { @silvea_message.reload.conversation_id }
    call_tool("get_conversation", id: silvea_conversation)
    assert_equal [ "Commande de plants", "Silvéa" ], [ structured.dig("conversation", "subject"), structured.dig("account", "name") ]

    call_tool("create_draft", message_id: @silvea_message.id, body: "Merci !")
    assert_equal [ "contact@silvea.be", "Silvéa" ], [ structured.dig("draft", "mailbox"), structured.dig("account", "name") ]
    assert with_account(@silvea) { Draft.exists?(structured.dig("draft", "id")) }

    call_tool("list_drafts")
    assert_equal [ "Silvéa" ], structured["drafts"].map { |d| d.dig("account", "name") }
  end

  test "isolation still holds: other people's clients stay out of reach" do
    lea_message = create_message(@silvea, "lea@silvea.be", "Privé", 1.hour.ago, user: users(:lea))
    @token = authorize_and_get_tokens["access_token"]

    lea_conversation = with_account(@silvea) { lea_message.reload.conversation_id }
    call_tool("get_conversation", id: lea_conversation)
    assert result["isError"], "boîte de Silvéa à laquelle je n'ai pas accès"

    @token = ApiToken.create!(user: users(:mohammad), account: @semisto, name: "CLI").token
    silvea_conversation = with_account(@silvea) { @silvea_message.reload.conversation_id }
    call_tool("get_conversation", id: silvea_conversation)
    assert result["isError"], "client dont je ne suis pas membre"
    call_tool("search_conversations", account_id: @silvea.id)
    assert result["isError"]

    call_tool("search_conversations", account_id: 0)
    assert result["isError"]
  end

  test "a client I leave drops out of the connection" do
    @token = authorize_and_get_tokens["access_token"]
    Membership.find_by!(account: @silvea, user: @michael).destroy!

    call_tool("whoami")
    assert_equal "Semisto", structured.dig("account", "name")
    call_tool("get_conversation", id: with_account(@silvea) { @silvea_message.reload.conversation_id })
    assert result["isError"]
  end

  test "the agent works in one client and never sees account_id" do
    definitions = with_account(accounts(:semisto)) { AgentToolbox.new(@michael).definitions }
    assert definitions.none? { |definition| definition[:input_schema][:properties].key?(:account_id) }
  end

  private

  def create_message(account, address, subject, sent_at, user: @michael)
    with_account(account) do
      mailbox = Mailbox.create!(provider: "gmail", address: address)
      mailbox.grant!(user, "send")
      sender = "client@#{address.split("@").last}"
      message = mailbox.messages.create!(provider_uid: subject, thread_key: subject, subject: subject,
        from_address: sender, sent_at: sent_at, body_text: "Bonjour", labels: %w[INBOX])
      Screening.decide!(user, sender, "accepted")
      Conversation.rebuild_for(mailbox)
      message
    end
  end

  def register_client
    post oauth_registration_path, params: { client_name: "Claude", redirect_uris: [ REDIRECT_URI ] }, as: :json
    response.parsed_body
  end

  def authorization_params(client, verifier)
    { client_id: client["client_id"], redirect_uri: REDIRECT_URI, response_type: "code", state: "xyz",
      code_challenge: Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false), code_challenge_method: "S256" }
  end

  def authorize_and_get_tokens
    client = register_client
    verifier = SecureRandom.urlsafe_base64(48)
    sign_in_as @michael
    post oauth_authorization_path, params: authorization_params(client, verifier).merge(decision: "approve", sg_account_id: "")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    post oauth_token_path, params: { grant_type: "authorization_code", client_id: client["client_id"], code: code, redirect_uri: REDIRECT_URI, code_verifier: verifier }
    assert_response :success
    response.parsed_body
  end

  def call_tool(name, **arguments)
    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json,
      headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
    assert_response :success
  end

  def result = response.parsed_body["result"]
  def structured = result["structuredContent"]
end
