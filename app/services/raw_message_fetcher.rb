# Récupère l'email brut chez le fournisseur, pour les pièces jointes téléchargées à la demande.
class RawMessageFetcher
  def self.fetch(message) = new(message).fetch

  def initialize(message)
    @message = message
    @mailbox = message.mailbox
  end

  def fetch
    @mailbox.gmail? ? fetch_gmail : fetch_imap
  end

  private

  def fetch_gmail
    service = GoogleOauth.gmail_service(GoogleOauth.for_mailbox(@mailbox))
    service.get_user_message("me", @message.provider_uid, format: "raw").raw
  end

  def fetch_imap
    folder = @message.mail_folder
    uid = @message.provider_uid.split("/").last.to_i
    imap = ImapSync.connect(@mailbox.credentials)
    if imap.status(folder.name, %w[UIDVALIDITY])["UIDVALIDITY"] != folder.uidvalidity
      raise "Le dossier #{folder.name} a changé sur le serveur : relance une synchro."
    end

    imap.examine(folder.name)

    imap.uid_fetch(uid, "BODY.PEEK[]")&.first&.attr&.fetch("BODY[]")
  ensure
    imap&.logout rescue nil
    imap&.disconnect rescue nil
  end
end
