# Connexion par passkey : l'appareil propose les passkeys de SG Mail, sans saisir d'adresse.
class PasskeySessionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render json: { error: "Trop de tentatives, réessaie dans quelques minutes." }, status: :too_many_requests }

  def options
    options = Passkey.relying_party(request).options_for_authentication(user_verification: "preferred")
    session[:passkey_authentication_challenge] = options.challenge
    render json: options
  end

  def create
    challenge = session.delete(:passkey_authentication_challenge)
    credential, passkey = Passkey.relying_party(request).verify_authentication(params.require(:credential).to_unsafe_h, challenge) do |presented|
      Passkey.find_by!(external_id: presented.id)
    end
    passkey.update!(sign_count: credential.sign_count, last_used_at: Time.current)
    start_new_session_for passkey.user
    render json: { redirect: after_authentication_url }
  rescue WebAuthn::Error, ActiveRecord::RecordNotFound, ActionController::ParameterMissing
    render json: { error: "Cette passkey n'est pas reconnue." }, status: :unauthorized
  end
end
