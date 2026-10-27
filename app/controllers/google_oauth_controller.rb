class GoogleOauthController < ApplicationController
  rescue_from KeyError do
    redirect_to mailboxes_path, alert: "GOOGLE_CLIENT_ID et GOOGLE_CLIENT_SECRET manquent dans .env."
  end

  def new
    session[:google_oauth_state] = SecureRandom.hex(16)
    redirect_to oauth_client.authorization_uri(
      access_type: "offline",
      prompt: "consent", # pour recevoir un refresh_token à chaque connexion
      include_granted_scopes: "true",
      state: session[:google_oauth_state]
    ).to_s, allow_other_host: true
  end

  def callback
    if params[:error].present? || params[:state] != session.delete(:google_oauth_state)
      return redirect_to mailboxes_path, alert: "Connexion Google annulée ou invalide (#{params[:error]})."
    end

    client = oauth_client
    client.code = params[:code]
    client.fetch_access_token!

    address = GoogleOauth.gmail_service(client).get_user_profile("me").email_address
    mailbox = Mailbox.find_or_initialize_by(provider: "gmail", address: address)
    mailbox.credentials = {
      "refresh_token" => client.refresh_token.presence || mailbox.credentials&.dig("refresh_token"),
      "access_token" => client.access_token,
      "expires_at" => client.expires_at&.to_i
    }
    mailbox.save!

    SyncMailboxJob.perform_later(mailbox)
    redirect_to mailbox, notice: "#{address} connectée. Import lancé."
  end

  private

  def oauth_client
    GoogleOauth.client(redirect_uri: "#{request.base_url}/auth/google_oauth2/callback")
  end
end
