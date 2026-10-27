require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @mailbox.grant!(users(:mohammad), "send")
      @message = @mailbox.messages.create!(provider_uid: "a", thread_key: "t1", subject: "Inscription formation",
        from_address: "anne@example.org", sent_at: 1.day.ago, body_text: "Bonjour", labels: %w[INBOX])
      Conversation.rebuild_for(@mailbox)
    end
    @token = ApiToken.create!(user: users(:mohammad), account: @semisto, name: "Claude Code").token
  end

  test "requires a token" do
    post mcp_path, params: rpc("tools/list"), headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "lists tools, searches, drafts a reply" do
    call_mcp("initialize", protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" })
    assert_equal "sg-mail", result["serverInfo"]["name"]

    call_mcp("tools/list")
    assert_includes result["tools"].map { |tool| tool["name"] }, "send_draft"

    call_tool("search_conversations", query: "formation")
    conversation = result["structuredContent"]["conversations"].sole
    assert_equal "Inscription formation", conversation["subject"]

    call_tool("create_draft", message_id: @message.id, body: "Merci !")
    draft = result["structuredContent"]["draft"]
    assert_equal [ "anne@example.org" ], draft["to"]
    assert_equal "draft", draft["status"]
    assert_empty enqueued_jobs, "un brouillon n'est jamais envoyé tout seul"

    call_tool("get_conversation", id: conversation["id"] + 1000)
    assert result["isError"]
  end

  private

  def rpc(method, **params) = { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json

  def call_mcp(method, **params)
    post mcp_path, params: rpc(method, **params),
      headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
    assert_response :success
  end

  def call_tool(name, **arguments) = call_mcp("tools/call", name: name, arguments: arguments)

  def result = response.parsed_body["result"]
end
