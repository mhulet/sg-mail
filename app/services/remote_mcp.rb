# SG Mail client MCP d'un outil connecté, au nom d'une personne (IntegrationConnection) : connexion OAuth 2.1
# (découverte, inscription dynamique, PKCE, rafraîchissement : le gem mcp s'en charge), liste et appel des outils.
class RemoteMcp
  CALLBACK_PATH = "/integrations/callback".freeze
  TOOLS_TTL = 1.hour
  TIMEOUT = 30

  # La personne doit (re)connecter son compte : authorization_url l'y emmène.
  class AuthorizationRequired < StandardError
    attr_reader :authorization_url

    def initialize(authorization_url = nil)
      super("Authorization required")
      @authorization_url = authorization_url
    end
  end

  # Qui parle vraiment au serveur (remplacé dans les tests) : reçoit la connexion et le provider OAuth,
  # rend un objet qui répond à connect, tools, call_tool et instructions, comme MCP::Client.
  cattr_accessor :client_factory, default: ->(connection, provider) {
    transport = MCP::Client::HTTP.new(url: connection.integration.mcp_url, oauth: provider) do |faraday|
      faraday.options.timeout = TIMEOUT
      faraday.options.open_timeout = 10
    end
    MCP::Client.new(transport: transport)
  }

  # Termine une autorisation au retour de l'outil (remplacé dans les tests).
  cattr_accessor :finisher, default: ->(connection, provider, params) {
    MCP::Client::OAuth::Flow.new(provider: provider)
      .finish!(server_url: MCP::Client::OAuth::Discovery.canonicalize_url(connection.integration.mcp_url), callback_params: params)
  }

  def initialize(connection)
    @connection = connection
  end

  # Lance la connexion : AuthorizationRequired avec l'adresse où envoyer la personne, sauf si ses jetons valent encore.
  def authorize!(redirect_uri)
    @connection.update!(oauth: (@connection.oauth || {}).merge("redirect_uri" => redirect_uri))
    refresh!
  end

  # Au retour de l'outil : échange le code contre des jetons, puis lit les outils et l'identité distante.
  def finish!(params)
    self.class.finisher.call(@connection, provider, params.to_h.slice("code", "state", "iss", "error"))
    refresh!
  end

  # Relit les outils, les consignes du serveur et l'identité distante.
  def refresh!
    with_client do |client|
      tools = client.tools.map do |tool|
        { "name" => tool.name, "description" => tool.description.to_s, "input_schema" => tool.input_schema || { "type" => "object" },
          "read_only" => tool.annotations.is_a?(Hash) && tool.annotations["readOnlyHint"] == true }
      end
      @connection.update!(tools: tools, instructions: client.instructions.to_s.first(4000).presence, tools_fetched_at: Time.current,
        connected_at: @connection.connected_at || Time.current, remote_identity: identity(client, tools) || @connection.remote_identity)
    end
  end

  def refresh_if_stale!
    refresh! if @connection.tools_fetched_at.nil? || @connection.tools_fetched_at < TOOLS_TTL.ago
  rescue StandardError => error
    Rails.logger.warn("Outil #{@connection.integration_id} : #{error.class} #{error.message}")
  end

  # { "text" => …, "error" => true|false }, comme AgentToolbox#call.
  def call(name, arguments)
    with_client do |client|
      response = client.call_tool(name: name, arguments: arguments)
      result = response.is_a?(Hash) ? (response["result"] || {}) : {}
      { "text" => text_of(result), "error" => result["isError"] == true }
    end
  rescue AuthorizationRequired
    { "text" => "#{@connection.integration.name} is disconnected: the person must reconnect it in SG Mail (Settings → Tools).", "error" => true }
  rescue StandardError => error
    { "text" => "#{@connection.integration.name} failed: #{error.class.name.demodulize} #{error.message.to_s.first(300)}", "error" => true }
  end

  private

  def with_client
    client = self.class.client_factory.call(@connection, provider)
    client.connect(client_info: { name: "SG Mail", version: "1.0" })
    yield client
  rescue MCP::Client::OAuth::Flow::AuthorizationPendingError => error
    @connection.update!(connected_at: nil)
    raise AuthorizationRequired, error.authorization_url
  rescue MCP::Client::OAuth::Flow::AuthorizationError
    @connection.update!(connected_at: nil)
    raise AuthorizationRequired
  ensure
    client&.transport&.close if client.respond_to?(:transport) && client.transport.respond_to?(:close)
  end

  def provider
    redirect_uri = @connection.redirect_uri or raise AuthorizationRequired
    MCP::Client::OAuth::Provider.new(
      client_metadata: { client_name: "SG Mail", redirect_uris: [ redirect_uri ], grant_types: %w[authorization_code refresh_token],
                         response_types: %w[code], token_endpoint_auth_method: "none" },
      redirect_uri: redirect_uri, redirect_handler: ->(_url) { }, storage: @connection,
      pending_authorization_max_age: IntegrationConnection::PENDING_MAX_AGE.to_i
    )
  end

  # Le compte de la personne dans l'outil, quand il a un outil whoami : l'adresse email s'il en donne une.
  def identity(client, tools)
    whoami = tools.find { |tool| tool["name"] == "whoami" } or return
    text = text_of(client.call_tool(name: "whoami", arguments: {}).fetch("result", {}))
    text[/[\w.+-]+@[\w-]+(\.[\w-]+)+/] || text.lines.first.to_s.strip.first(80).presence
  rescue StandardError
    nil
  end

  def text_of(result)
    blocks = Array(result["content"]).filter_map { |block| block["text"] if block.is_a?(Hash) }
    text = blocks.join("\n")
    text = result["structuredContent"].to_json if text.blank? && result["structuredContent"]
    text.to_s.first(60_000)
  end
end
