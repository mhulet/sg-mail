require "test_helper"

class IntegrationsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Un serveur MCP distant, comme My Semisto : whoami, une lecture et une écriture.
  class FakeServer
    attr_accessor :pending, :expired
    attr_reader :calls

    def initialize
      @calls = []
    end

    def connect(**)
      raise MCP::Client::OAuth::Flow::AuthorizationPendingError.new("pending", authorization_url: URI("https://my.semisto.test/authorize?state=s1")) if pending
      raise MCP::Client::OAuth::Flow::AuthorizationError, "invalid_grant" if expired
    end

    def instructions = "My Semisto: projects, to-dos and messages."

    def tools
      [ MCP::Client::Tool.new(name: "whoami", description: "Who am I", input_schema: { "type" => "object" }, annotations: { "readOnlyHint" => true }),
        MCP::Client::Tool.new(name: "search", description: "Search projects", input_schema: { "type" => "object", "properties" => { "q" => { "type" => "string" } } },
          annotations: { "readOnlyHint" => true }),
        MCP::Client::Tool.new(name: "api_write", description: "Create a to-do", input_schema: { "type" => "object" }, annotations: nil) ]
    end

    def call_tool(name:, arguments:)
      @calls << [ name, arguments ]
      text = name == "whoami" ? "Michael Hulet <m.hulet@semisto.org>, hubs: Semisto" : "#{name} ok"
      { "result" => { "content" => [ { "type" => "text", "text" => text } ], "isError" => false } }
    end
  end

  setup do
    @semisto = accounts(:semisto)
    @server = FakeServer.new
    @original = [ RemoteMcp.client_factory, RemoteMcp.finisher, AgentRun.client ]
    RemoteMcp.client_factory = ->(_connection, _provider) { @server }
    RemoteMcp.finisher = ->(connection, _provider, params) { connection.save_tokens("access_token" => "at-#{params["code"]}") }
    @calls = []
    @replies = []
    AgentRun.client = ->(**params) { @calls << params; @replies.shift || text_reply("…") }
  end

  teardown { RemoteMcp.client_factory, RemoteMcp.finisher, AgentRun.client = @original }

  test "an admin declares a tool, members cannot" do
    sign_in_as users(:mohammad)
    post integrations_path(account_id: @semisto.id), params: { integration: { name: "My Semisto", mcp_url: "https://my.semisto.test/mcp" } }
    assert_equal 0, with_account(@semisto) { Integration.count }

    sign_in_as users(:michael)
    post integrations_path(account_id: @semisto.id), params: { integration: { name: "Claudy", mcp_url: "http://claudy.test/mcp" } }
    assert_response :unprocessable_entity
    post integrations_path(account_id: @semisto.id), params: { integration: { name: "My Semisto", mcp_url: "https://my.semisto.test/mcp" } }
    assert_equal "mysemisto", with_account(@semisto) { Integration.sole.slug }

    sign_in_as users(:mohammad)
    get integrations_path(account_id: @semisto.id)
    assert_select "table.integrations th", /My Semisto/
    assert_select "button", text: "Connecter mon compte"
  end

  test "each member connects their own account, which may differ from their SG Mail address" do
    integration = create_integration
    https!
    sign_in_as users(:michael)
    @server.pending = true
    post integration_connection_path(integration, account_id: @semisto.id)
    assert_redirected_to "https://my.semisto.test/authorize?state=s1"
    connection = with_account(@semisto) { IntegrationConnection.sole }
    assert_equal "https://www.example.com/integrations/callback", connection.redirect_uri
    assert_not connection.connected?

    @server.pending = false
    get integration_callback_path(code: "c1", state: "s1")
    assert_redirected_to integrations_path(account_id: @semisto.id)
    assert_match "connecté en tant que m.hulet@semisto.org", flash[:notice]
    connection.reload
    assert connection.connected?
    assert_equal "at-c1", connection.tokens["access_token"]
    assert_equal %w[whoami search api_write], connection.tools_list.map { |t| t["name"] }
    assert_not_includes IntegrationConnection.connection.select_value("SELECT oauth FROM integration_connections"), "at-c1", "jetons chiffrés"

    get integration_callback_path(code: "c2", state: "s1")
    assert_match "expirée", flash[:alert]

    delete integration_connection_path(integration, account_id: @semisto.id)
    assert_equal 0, with_account(@semisto) { IntegrationConnection.count }
  end

  test "the agent reads in a connected tool at once and waits for confirmation before writing there" do
    connect(users(:michael))
    @semisto.update!(agent_enabled: true)
    @replies << tool_reply("toolu_1", "mysemisto__search", { "q" => "Verger" })
    @replies << tool_reply("toolu_2", "mysemisto__api_write", { "path" => "/recordings", "title" => "Rappeler Anne" })
    @replies << text_reply("C'est fait.")
    sign_in_as users(:michael)

    perform_enqueued_jobs { post agent_chats_path(account_id: @semisto.id), params: { text: "Crée une to-do dans My Semisto" } }
    names = @calls.first[:tools].map { |tool| tool[:name] }
    assert_includes names, "mysemisto__search"
    assert_includes names, "add_note"
    assert_includes @calls.first[:system_].last[:text], "signed in as m.hulet@semisto.org"
    assert_equal [ "search", { "q" => "Verger" } ], @server.calls.last

    chat = with_account(@semisto) { AgentChat.sole }
    write = with_account(@semisto) { chat.agent_actions.last }
    assert_equal [ "pending", true ], [ write.status, write.writes ]
    get agent_chat_path(chat, account_id: @semisto.id)
    assert_select ".agent-action.pending", text: /My Semisto : api write/
    assert_select ".agent-action.pending", text: /Rappeler Anne/

    perform_enqueued_jobs { patch agent_chat_agent_action_path(chat, write, account_id: @semisto.id), params: { decision: "confirm" } }
    assert_equal [ "api_write", { "path" => "/recordings", "title" => "Rappeler Anne" } ], @server.calls.last
    assert_equal "idle", chat.reload.status
  end

  test "a revoked account is reported to the agent and shown as disconnected" do
    connection = connect(users(:michael))
    @server.expired = true
    result = with_account(@semisto) { AgentToolbox.new(users(:michael)).call("mysemisto__search", { "q" => "x" }) }
    assert result["error"]
    assert_match "reconnect", result["text"]
    assert_not with_account(@semisto) { connection.reload.connected? }

    @semisto.update!(agent_enabled: true)
    sign_in_as users(:michael)
    perform_enqueued_jobs { post agent_chats_path(account_id: @semisto.id), params: { text: "Bonjour" } }
    assert_not_includes @calls.last[:tools].map { |tool| tool[:name] }, "mysemisto__search"
    assert_includes @calls.last[:system_].last[:text], "My Semisto: not connected"
  end

  test "a connection belongs to one person: others do not get its tools" do
    connect(users(:michael))
    names = with_account(@semisto) { AgentToolbox.new(users(:mohammad)).definitions.map { |tool| tool[:name] } }
    assert_not_includes names, "mysemisto__search"
  end

  private

  def create_integration
    with_account(@semisto) { Integration.create!(name: "My Semisto", mcp_url: "https://my.semisto.test/mcp") }
  end

  def connect(user)
    integration = create_integration
    with_account(@semisto) do
      connection = integration.connections.create!(user: user, oauth: { "redirect_uri" => "https://sg.test/integrations/callback" })
      RemoteMcp.new(connection).refresh!
      connection
    end
  end

  def text_reply(text)
    { "content" => [ { "type" => "text", "text" => text } ], "stop_reason" => "end_turn", "usage" => { "input_tokens" => 1000, "output_tokens" => 100 } }
  end

  def tool_reply(id, name, input)
    { "content" => [ { "type" => "tool_use", "id" => id, "name" => name, "input" => input } ],
      "stop_reason" => "tool_use", "usage" => { "input_tokens" => 1000, "output_tokens" => 50 } }
  end
end
