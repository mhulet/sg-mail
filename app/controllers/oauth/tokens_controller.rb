class Oauth::TokensController < ActionController::API
  rate_limit to: 30, within: 1.minute, only: %i[create revoke],
    with: -> { render json: { error: "slow_down" }, status: :too_many_requests }

  before_action :set_client

  def create
    case params[:grant_type]
    when "authorization_code" then exchange_code
    when "refresh_token" then refresh
    else token_error("unsupported_grant_type")
    end
  end

  # RFC 7009 : répond toujours 200, même pour un jeton inconnu.
  def revoke
    token = Oauth::Token.find_by_refresh_token(params[:token]) || Oauth::Token.find_by(access_token_digest: Oauth.digest(params[:token]))
    token.revoke! if token && token.client == @client
    head :ok
  end

  private

  def set_client
    @client = Oauth::Client.find_by(uid: params[:client_id])
    token_error("invalid_client", status: :unauthorized) unless @client
  end

  def exchange_code
    code = Oauth::AuthorizationCode.find_by_code(params[:code])
    valid = code && code.client == @client && code.redirect_uri == params[:redirect_uri] && code.verifier_matches?(params[:code_verifier])
    token = code.redeem! if valid
    token ? render_token(token) : token_error("invalid_grant")
  end

  def refresh
    token = Oauth::Token.find_by_refresh_token(params[:refresh_token])
    new_token = token.rotate! if token && token.client == @client
    new_token ? render_token(new_token) : token_error("invalid_grant")
  end

  def render_token(token)
    response.set_header("Cache-Control", "no-store")
    render json: token.as_token_response
  end

  def token_error(error, status: :bad_request)
    render json: { error: error }, status: status
  end
end
