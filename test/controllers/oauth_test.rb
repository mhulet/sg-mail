require "test_helper"

class OauthTest < ActionDispatch::IntegrationTest
  REDIRECT_URI = "https://claude.ai/api/mcp/auth_callback".freeze

  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      mailbox.grant!(users(:michael), "send")
      mailbox.messages.create!(provider_uid: "a", thread_key: "t1", subject: "Inscription",
        from_address: "anne@example.org", sent_at: 1.day.ago, body_text: "Bonjour", labels: %w[INBOX])
      Conversation.rebuild_for(mailbox)
    end
  end

  test "discovery documents point to the authorization server" do
    get "/.well-known/oauth-protected-resource/mcp"
    assert_equal "http://www.example.com/mcp", response.parsed_body["resource"]
    get "/.well-known/oauth-authorization-server"
    assert_equal "http://www.example.com/oauth/token", response.parsed_body["token_endpoint"]
  end

  test "mcp advertises the resource metadata when the token is missing" do
    post mcp_path, params: initialize_request, as: :json
    assert_response :unauthorized
    assert_match %r{resource_metadata="http://www.example.com/.well-known/oauth-protected-resource/mcp"}, response.headers["WWW-Authenticate"]
  end

  test "registration refuses unsafe redirect URIs" do
    post oauth_registration_path, params: { client_name: "Evil", redirect_uris: [ "http://evil.example/callback" ] }, as: :json
    assert_response :bad_request
  end

  test "full flow: register, sign in, choose the client, approve, then use the MCP" do
    tokens = authorize_and_get_tokens
    assert tokens["access_token"].start_with?("sgma_")

    mcp(tokens["access_token"], { jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "whoami", arguments: {} } })
    result = response.parsed_body.dig("result", "structuredContent")
    assert_equal [ "Michael", "Semisto", [ "formations@semisto.org" ] ],
      [ result.dig("user", "name"), result.dig("account", "name"), result["mailboxes"].map { |m| m["address"] } ]
  end

  test "codes are single use and need the PKCE verifier" do
    client = register_client
    verifier = SecureRandom.urlsafe_base64(48)
    sign_in_as users(:michael)
    post oauth_authorization_path, params: authorization_params(client, verifier).merge(decision: "approve", sg_account_id: @semisto.id)
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    exchange(client, code, "wrong")
    assert_equal "invalid_grant", response.parsed_body["error"]
    exchange(client, code, verifier)
    assert_response :success
    exchange(client, code, verifier)
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "refresh tokens rotate, and the connection can be removed in SG Mail" do
    tokens = authorize_and_get_tokens
    client_id = Oauth::Client.last.uid

    post oauth_token_path, params: { grant_type: "refresh_token", client_id: client_id, refresh_token: tokens["refresh_token"] }
    refreshed = response.parsed_body
    post oauth_token_path, params: { grant_type: "refresh_token", client_id: client_id, refresh_token: tokens["refresh_token"] }
    assert_equal "invalid_grant", response.parsed_body["error"]

    get api_tokens_path(account_id: @semisto.id)
    assert_select "td", "Claude"
    delete oauth_connection_path(Oauth::Client.last, account_id: @semisto.id)
    mcp(refreshed["access_token"], initialize_request)
    assert_response :unauthorized
  end

  test "the consent screen requires signing in, can be denied, and checks the return address" do
    client = register_client
    get oauth_authorization_path(authorization_params(client, "verifier"))
    assert_redirected_to new_session_path

    sign_in_as users(:michael)
    get oauth_authorization_path(authorization_params(client, "verifier"))
    assert_response :success
    assert_select "button", "Autoriser"

    post oauth_authorization_path, params: authorization_params(client, "verifier").merge(decision: "deny")
    assert_match "error=access_denied", response.location
    assert_match "state=xyz", response.location

    get oauth_authorization_path(authorization_params(client, "verifier").merge(redirect_uri: "https://evil.example/cb"))
    assert_response :bad_request
  end

  test "a token stops working when its person leaves the client" do
    tokens = authorize_and_get_tokens(users(:mohammad))
    memberships(:mohammad_semisto).destroy!
    mcp(tokens["access_token"], initialize_request)
    assert_response :unauthorized
  end

  private

  def initialize_request
    { jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } } }
  end

  def mcp(token, payload)
    post mcp_path, params: payload, as: :json, headers: { "Authorization" => "Bearer #{token}", "Accept" => "application/json, text/event-stream" }
  end

  def register_client
    post oauth_registration_path, params: { client_name: "Claude", redirect_uris: [ REDIRECT_URI ] }, as: :json
    assert_response :created
    response.parsed_body
  end

  def authorization_params(client, verifier)
    { client_id: client["client_id"], redirect_uri: REDIRECT_URI, response_type: "code", state: "xyz",
      code_challenge: Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false), code_challenge_method: "S256" }
  end

  def exchange(client, code, verifier)
    post oauth_token_path, params: { grant_type: "authorization_code", client_id: client["client_id"], code: code, redirect_uri: REDIRECT_URI, code_verifier: verifier }
  end

  def authorize_and_get_tokens(user = users(:michael))
    client = register_client
    verifier = SecureRandom.urlsafe_base64(48)
    sign_in_as user
    post oauth_authorization_path, params: authorization_params(client, verifier).merge(decision: "approve", sg_account_id: @semisto.id)
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    exchange(client, code, verifier)
    assert_response :success
    response.parsed_body
  end
end
