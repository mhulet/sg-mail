require "test_helper"
require_relative "../../cli/lib/sg_mail"

# Le CLI contre la vraie API, via la pile Rack de l'app (sans serveur ni réseau).
class SgMailCliTest < ActionDispatch::IntegrationTest
  class RackClient < SgMail::Client
    def initialize(session, token)
      super("http://www.example.com", token)
      @session = session
    end

    private

    def request(klass, path, query: {}, body: nil)
      verb = klass.name.demodulize.downcase.to_sym
      headers = { "Authorization" => "Bearer #{@token}", "Accept" => "application/json" }
      params = verb == :get ? query.compact : body.to_h.compact.to_json
      headers["Content-Type"] = "application/json" unless verb == :get
      @session.public_send(verb, "/api/v1/#{path}", params: params, headers: headers)
      data = @session.response.body.empty? ? {} : JSON.parse(@session.response.body)
      raise Error, error_message(Struct.new(:code).new(@session.response.status.to_s), data) unless @session.response.successful?

      data
    end
  end

  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      mailbox.grant!(users(:mohammad), "send")
      @message = mailbox.messages.create!(provider_uid: "a", thread_key: "t1", subject: "Inscription",
        from_address: "anne@example.org", sent_at: 1.day.ago, body_text: "Bonjour", labels: %w[INBOX])
      Conversation.rebuild_for(mailbox)
    end
    @client = RackClient.new(self, ApiToken.create!(user: users(:mohammad), account: @semisto, name: "CLI").token)
  end

  teardown { SgMail::Cli.client = nil }

  test "inbox, reply as a draft, tasks" do
    assert_match(/● \d+ +anne@example.org +Inscription/, run_cli("inbox"))
    assert_match(/Brouillon \d+ prêt \(pas envoyé\)/, run_cli("reply", @message.id.to_s, "Merci"))
    assert_empty enqueued_jobs
    assert_match(/Tâche créée : \d+\. Relancer · Mohammad/, run_cli("task-add", "Relancer", "--message", @message.id.to_s))
    assert_equal "Inscription", JSON.parse(run_cli("search", "inscri", "--json"))["conversations"].sole["subject"]
  end

  test "screener, accept, block" do
    with_account(@semisto) do
      travel 1.hour
      Mailbox.sole.messages.create!(provider_uid: "z", thread_key: "t2", subject: "Partenariat", from_address: "zoe@example.org",
        from_name: "Zoé", sent_at: Time.current, labels: %w[INBOX])
      Conversation.rebuild_for(Mailbox.sole)
    end

    assert_match(/zoe@example.org +Zoé +Partenariat/, run_cli("screener"))
    assert_equal "zoe@example.org accepté.\n", run_cli("accept", "zoe@example.org")
    assert_match(/Partenariat/, run_cli("inbox"))
    run_cli("block", "zoe@example.org")
    assert_equal "bloqué : zoe@example.org", run_cli("screener").lines.last.strip
    assert_no_match(/Partenariat/, run_cli("inbox"))
  end

  test "errors are readable" do
    error = assert_raises(SgMail::Client::Error) { run_cli("show", "999999") }
    assert_equal "Introuvable, ou pas d'accès.", error.message
  end

  private

  def run_cli(*args)
    SgMail::Cli.client = @client
    capture_io { SgMail::Cli.start(args) }.first
  end
end
