# Pièces jointes, rapatriées chez le fournisseur à la première ouverture puis gardées (voir AttachmentCache).
class AttachmentsController < ApplicationController
  include AccountScoped
  include AttachmentServing
  before_action :set_message

  # Téléchargement, ou affichage dans la visionneuse (?view=1) pour les images et les PDF.
  def show
    attachment = find_attachment
    blob = AttachmentCache.new(@message).blob(attachment["index"]) or raise ActiveRecord::RecordNotFound

    AccessLog.record!(Current.user, @message.conversation, via: "web", action: "attachment", message: @message, detail: attachment["filename"])

    if params[:view].present? && viewable?(blob)
      serve_inline(blob)
    else
      send_data blob.download, filename: attachment["filename"], type: blob.content_type, disposition: "attachment"
    end
  end

  # Vignette d'une image ou première page d'un PDF. Si le serveur ne sait pas la faire, la carte garde son icône.
  def thumbnail
    blob = AttachmentCache.new(@message).blob(find_attachment["index"]) or raise ActiveRecord::RecordNotFound
    serve_thumbnail(blob)
  end

  # Toutes les pièces jointes du message, en un .zip.
  def archive
    attachments = @message.listed_attachments
    raise ActiveRecord::RecordNotFound if attachments.empty?

    cache = AttachmentCache.new(@message)
    names = Hash.new(0)
    zip = Zip::OutputStream.write_buffer do |stream|
      attachments.each do |attachment|
        blob = cache.blob(attachment["index"]) or next
        stream.put_next_entry(unique_name(attachment["filename"], names))
        stream.write(blob.download)
      end
    end

    AccessLog.record!(Current.user, @message.conversation, via: "web", action: "attachment", message: @message,
      detail: "Toutes les pièces jointes (#{attachments.size})")
    send_data zip.string, filename: "pieces-jointes-#{@message.conversation.title.to_s.parameterize.first(60).presence || @message.id}.zip",
      type: "application/zip", disposition: "attachment"
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

  def find_attachment
    @message.attachments.find { |a| a["index"] == params[:id].to_i } or raise ActiveRecord::RecordNotFound
  end

  # Deux pièces du même nom dans le .zip : « devis.pdf », puis « devis (2).pdf ».
  def unique_name(filename, names)
    names[filename] += 1
    return filename if names[filename] == 1

    extension = File.extname(filename)
    "#{File.basename(filename, extension)} (#{names[filename]})#{extension}"
  end
end
