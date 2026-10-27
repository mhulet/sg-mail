# Écran de consentement. La connexion passe par la page de connexion habituelle de SG Mail.
# Une personne membre de plusieurs clients choisit celui que Claude pourra lire.
class Oauth::AuthorizationsController < ApplicationController
  before_action :set_request_params
  before_action :set_memberships

  def new
    @client = Oauth::Client.find_by(uid: @params[:client_id])
    return render_invalid("Application inconnue.") unless @client
    return render_invalid("Adresse de retour non autorisée.") unless @client.redirect_uri?(@params[:redirect_uri])
    return render_invalid("Tu ne fais partie d'aucun client SG Mail.") if @memberships.empty?

    error = request_error
    redirect_with(error: error) if error
  end

  def create
    @client = Oauth::Client.find_by(uid: @params[:client_id])
    return render_invalid("Application inconnue.") unless @client&.redirect_uri?(@params[:redirect_uri])
    return redirect_with(error: request_error) if request_error
    return redirect_with(error: "access_denied") unless params[:decision] == "approve"

    membership = @memberships.find { |m| m.account_id == params[:sg_account_id].to_i } || (@memberships.first if @memberships.one?)
    return redirect_with(error: "access_denied") unless membership

    code = @client.authorization_codes.create!(user: Current.user, account: membership.account, redirect_uri: @params[:redirect_uri],
      code_challenge: @params[:code_challenge], resource: @params[:resource])
    redirect_with(code: code.code)
  end

  private

  def set_request_params
    @params = params.permit(:client_id, :redirect_uri, :response_type, :code_challenge, :code_challenge_method, :state, :scope, :resource)
  end

  def set_memberships
    @memberships = Current.user.memberships.includes(:account).sort_by { |m| m.account.name }
  end

  def request_error
    if @params[:response_type] != "code"
      "unsupported_response_type"
    elsif @params[:code_challenge].blank? || @params[:code_challenge_method] != "S256"
      "invalid_request"
    end
  end

  # Erreurs qu'on ne doit pas renvoyer vers une adresse de retour non vérifiée : affichées ici.
  def render_invalid(message)
    @message = message
    render :invalid, status: :bad_request
  end

  def redirect_with(**query)
    uri = URI.parse(@params[:redirect_uri])
    query = URI.decode_www_form(uri.query.to_s) + query.compact.to_a
    query << [ "state", @params[:state] ] if @params[:state].present?
    query << [ "iss", request.base_url ]
    uri.query = URI.encode_www_form(query)
    redirect_to uri.to_s, allow_other_host: true
  end
end
