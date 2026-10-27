require "json"
require "net/http"
require "uri"
require "fileutils"

module SgMail
  # Client HTTP de l'API /api/v1. Adresse et jeton : SG_MAIL_URL et SG_MAIL_TOKEN,
  # ou ~/.config/sg-mail/config.json (écrit par « sg-mail login »).
  class Client
    class Error < StandardError; end

    CONFIG_PATH = File.join(Dir.home, ".config", "sg-mail", "config.json")

    def self.from_config
      config = File.exist?(CONFIG_PATH) ? JSON.parse(File.read(CONFIG_PATH)) : {}
      url = ENV["SG_MAIL_URL"] || config["url"]
      token = ENV["SG_MAIL_TOKEN"] || config["token"]
      raise Error, "Pas encore connecté : sg-mail login URL JETON (jeton à créer dans SG Mail, menu « Jetons d'API »)." unless url && token

      new(url, token)
    end

    def self.save_config(url, token)
      FileUtils.mkdir_p(File.dirname(CONFIG_PATH))
      File.write(CONFIG_PATH, JSON.pretty_generate("url" => url, "token" => token))
      File.chmod(0o600, CONFIG_PATH)
    end

    def initialize(url, token)
      @base = URI(url.to_s.chomp("/"))
      @token = token
    end

    def get(path, params = {}) = request(Net::HTTP::Get, path, query: params)
    def post(path, body = {}) = request(Net::HTTP::Post, path, body: body)
    def patch(path, body = {}) = request(Net::HTTP::Patch, path, body: body)

    private

    def request(klass, path, query: {}, body: nil)
      uri = URI("#{@base}/api/v1/#{path}")
      query = query.reject { |_key, value| value.nil? || value == false }
      uri.query = URI.encode_www_form(query) if query.any?
      req = klass.new(uri)
      req["Authorization"] = "Bearer #{@token}"
      req["Accept"] = "application/json"
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body.compact)
      end
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }
      data = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      return data if response.is_a?(Net::HTTPSuccess)

      raise Error, error_message(response, data)
    end

    def error_message(response, data)
      case response.code
      when "401" then "Jeton refusé (révoqué, ou tu ne fais plus partie de ce client)."
      when "404" then "Introuvable, ou pas d'accès."
      else data["message"] || Array(data["messages"]).join(", ").then { |m| m.empty? ? "Erreur #{response.code} (#{data["error"]})" : m }
      end
    end
  end
end
