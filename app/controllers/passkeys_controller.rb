# Mes passkeys : en ajouter une depuis cet appareil, les renommer ou les retirer.
class PasskeysController < ApplicationController
  def index
    @passkeys = Current.user.passkeys.order(:created_at)
  end

  # Étape 1 : les options que le navigateur passe à navigator.credentials.create.
  def options
    options = Passkey.relying_party(request).options_for_registration(
      user: { id: Current.user.webauthn_id!, name: Current.user.email_address, display_name: Current.user.display_name },
      exclude: Current.user.passkeys.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "preferred" }
    )
    session[:passkey_registration_challenge] = options.challenge
    render json: options
  end

  # Étape 2 : la réponse de l'appareil, vérifiée avant d'enregistrer la clé publique.
  def create
    challenge = session.delete(:passkey_registration_challenge)
    credential = Passkey.relying_party(request).verify_registration(params.require(:credential).to_unsafe_h, challenge)
    Current.user.passkeys.create!(external_id: credential.id, public_key: credential.public_key, sign_count: credential.sign_count,
      name: params[:name].presence || Passkey.default_name(request.user_agent))
    flash[:notice] = "Passkey ajoutée : la prochaine fois, connecte-toi sans mot de passe."
    render json: { redirect: passkeys_path }
  rescue WebAuthn::Error, ActionController::ParameterMissing => e
    render json: { error: "Passkey refusée (#{e.message})." }, status: :unprocessable_entity
  end

  def destroy
    Current.user.passkeys.find(params[:id]).destroy!
    redirect_to passkeys_path, notice: "Passkey retirée."
  end
end
