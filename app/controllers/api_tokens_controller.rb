# Mes jetons personnels pour ce client (CLI, scripts, Claude Code).
class ApiTokensController < ApplicationController
  include AccountScoped

  def index
    @api_tokens = tokens.order(created_at: :desc)
    @api_token = ApiToken.new
    @connections = Oauth::Token.active.where(user: Current.user, account: Current.account).includes(:client)
      .group_by(&:client).transform_values { |tokens| tokens.filter_map(&:last_used_at).max || tokens.map(&:created_at).max }
  end

  # Le jeton n'est affiché qu'ici, une seule fois.
  def create
    @api_token = tokens.create!(name: params.dig(:api_token, :name).presence || "CLI")
    render :created
  end

  def destroy
    tokens.find(params[:id]).destroy!
    redirect_to api_tokens_path, notice: "Jeton révoqué."
  end

  private

  def tokens = ApiToken.where(user: Current.user, account: Current.account)
end
