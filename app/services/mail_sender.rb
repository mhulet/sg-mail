# Envoie un brouillon depuis sa boîte : API Gmail (le message rejoint son fil et « Envoyés »),
# ou SMTP + copie dans le dossier Envoyés pour l'IMAP.
class MailSender
  class Error < StandardError; end

  def initialize(draft, gmail_service: nil, smtp: nil, imap_connector: ImapSync.method(:connect))
    @draft = draft
    @mailbox = draft.mailbox
    @gmail_service = gmail_service
    @smtp = smtp
    @imap_connector = imap_connector
  end

  def deliver
    raise Error, "Ajoute au moins un destinataire." if @draft.recipients.empty?

    @mailbox.gmail? ? deliver_with_gmail : deliver_with_smtp
  end

  # Le message au format RFC 822, avec les en-têtes qui le rattachent au fil.
  def mail
    @mail ||= begin
      draft = @draft
      mail = Mail.new
      mail.from = sender
      mail.to = draft.to_addresses
      mail.cc = draft.cc_addresses if draft.cc_addresses.any?
      mail.bcc = draft.bcc_addresses if draft.bcc_addresses.any?
      mail.subject = draft.subject.to_s
      mail.date = Time.current
      mail.message_id = "<#{SecureRandom.uuid}@#{@mailbox.address.split("@").last}>"
      mail.charset = "UTF-8"

      if draft.reply? && (source = draft.source_message)&.message_id_header.present?
        parent = "<#{source.message_id_header}>"
        mail.in_reply_to = parent
        mail.references = [ *source_references(source), parent ].uniq.join(" ")
      end

      if draft.forward? && draft.source_message&.has_attachments
        mail.text_part = Mail::Part.new { content_type "text/plain; charset=UTF-8"; body draft.body.to_s }
        forwarded_attachments.each { |name, content| mail.attachments[name] = content }
      else
        mail.content_type = "text/plain; charset=UTF-8"
        mail.body = draft.body.to_s
      end
      mail
    end
  end

  private

  def sender
    name = @draft.user.name.presence
    address = Mail::Address.new(@mailbox.address)
    address.display_name = name if name
    address.to_s
  end

  # En IMAP, la clé de fil est le premier Message-ID du fil ; en Gmail, c'est un threadId.
  def source_references(source)
    return [] unless source.mailbox.imap?

    raw = source.thread_key
    raw.present? && raw != source.message_id_header ? [ "<#{raw}>" ] : []
  end

  def forwarded_attachments
    parser = MessageParser.new(RawMessageFetcher.fetch(@draft.source_message))
    parser.attachments.map { |a| [ a["filename"], parser.attachment_data(a["index"]) ] }
  end

  def deliver_with_gmail
    service = @gmail_service || GoogleOauth.gmail_service(GoogleOauth.for_mailbox(@mailbox))
    conversation = @draft.conversation
    thread_id = conversation.thread_key if @draft.reply? && conversation&.mailbox_id == @mailbox.id
    service.send_user_message("me", Google::Apis::GmailV1::Message.new(raw: mail.to_s, thread_id: thread_id))
  end

  def deliver_with_smtp
    credentials = @mailbox.credentials
    smtp = @smtp || Net::SMTP.new(credentials["smtp_host"].presence || credentials["host"], (credentials["smtp_port"].presence || 587).to_i)
    smtp.enable_starttls_auto if smtp.respond_to?(:enable_starttls_auto) && smtp.port.to_i != 465
    smtp.enable_tls if smtp.respond_to?(:enable_tls) && smtp.port.to_i == 465
    smtp.start(@mailbox.address.split("@").last, credentials["username"], credentials["password"], :plain) do |session|
      session.send_message(mail.to_s, @mailbox.address, @draft.recipients.map { |a| Mail::Address.new(a).address })
    end
    append_to_sent
  end

  # Copie dans le dossier Envoyés, pour la retrouver dans le fil et dans les autres clients mail.
  def append_to_sent
    sent = @mailbox.mail_folders.where.not(name: "INBOX").first&.name || "Sent"
    imap = @imap_connector.call(@mailbox.credentials)
    imap.append(sent, mail.to_s, [ :Seen ], Time.current)
  rescue Net::IMAP::Error, SocketError, SystemCallError => e
    Rails.logger.warn("Copie dans #{sent} impossible pour #{@mailbox.address} : #{e.message}")
  ensure
    imap&.logout rescue nil
    imap&.disconnect rescue nil
  end
end
