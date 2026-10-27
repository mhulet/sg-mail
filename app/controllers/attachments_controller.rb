# Pièces jointes, téléchargées chez le fournisseur au moment où on les demande.
class AttachmentsController < ApplicationController
  include AccountScoped
  before_action :set_message

  def show
    attachment = @message.attachments.find { |a| a["index"] == params[:id].to_i } or raise ActiveRecord::RecordNotFound
    data = MessageParser.new(RawMessageFetcher.fetch(@message)).attachment_data(attachment["index"])
    raise ActiveRecord::RecordNotFound unless data

    # Toujours en téléchargement : un fichier HTML ou SVG ne doit jamais s'ouvrir sur le domaine de SG Mail.
    send_data data, filename: attachment["filename"], type: attachment["content_type"], disposition: "attachment"
  end

  # Messages importés avant la liste des pièces jointes : on la complète à la demande.
  def create
    @message.update!(attachments: MessageParser.new(RawMessageFetcher.fetch(@message)).attachments)
    redirect_to conversation_path(@message.conversation, anchor: helpers.dom_id(@message))
  end

  private

  def set_message
    @message = Message.where(mailbox: Mailbox.accessible_by(Current.user)).find(params[:message_id])
  end
end
