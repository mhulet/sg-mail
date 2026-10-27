# L'app OAuth unique de SG Mail chez Google (décision D1).
module GoogleOauth
  SCOPES = [ "https://www.googleapis.com/auth/gmail.modify" ].freeze

  module_function

  def client(redirect_uri: nil, **tokens)
    Signet::OAuth2::Client.new(
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
      authorization_uri: "https://accounts.google.com/o/oauth2/auth",
      token_credential_uri: "https://oauth2.googleapis.com/token",
      scope: SCOPES,
      redirect_uri: redirect_uri,
      **tokens
    )
  end

  # Client authentifié pour une boîte déjà connectée.
  def for_mailbox(mailbox)
    creds = mailbox.credentials || {}
    client(
      refresh_token: creds["refresh_token"],
      access_token: creds["access_token"],
      expires_at: creds["expires_at"]
    )
  end

  def gmail_service(authorization)
    Google::Apis::GmailV1::GmailService.new.tap do |service|
      service.authorization = authorization
      service.client_options.application_name = "SG Mail"
    end
  end
end
