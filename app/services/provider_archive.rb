# Report de l'archivage chez le fournisseur (cadrage §6) : quand toutes les personnes qui ont accès
# à la boîte ont archivé un fil, il quitte aussi la boîte de réception Gmail (étiquette INBOX retirée).
# Le remettre dans la réception de SG Mail la lui rend.
#
# En IMAP, on ne déplace rien : SG Mail ne suit que INBOX et Envoyés, et un message déplacé
# disparaîtrait de ses fils. L'archivage reste alors propre à SG Mail.
class ProviderArchive
  def initialize(conversation, gmail_service: nil)
    @conversation = conversation
    @mailbox = conversation.mailbox
    @gmail_service = gmail_service
  end

  def archive = modify(remove: [ "INBOX" ])
  def unarchive = modify(add: [ "INBOX" ])

  private

  def modify(add: [], remove: [])
    return unless @mailbox.gmail? && @conversation.thread_key.present?

    request = Google::Apis::GmailV1::ModifyThreadRequest.new(add_label_ids: add, remove_label_ids: remove)
    service.modify_thread("me", @conversation.thread_key, request)
    # Sans attendre la synchro : les étiquettes locales suivent, et le fil quitte (ou rejoint) la réception.
    @conversation.messages.each { |message| message.update!(labels: (message.labels - remove + add).uniq) }
    @conversation.update!(in_inbox: add.include?("INBOX"))
  end

  def service = @gmail_service ||= GoogleOauth.gmail_service(GoogleOauth.for_mailbox(@mailbox))
end
