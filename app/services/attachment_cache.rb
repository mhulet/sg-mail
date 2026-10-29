# Les pièces jointes restent chez le fournisseur jusqu'à la première ouverture : on rapatrie alors toutes
# celles du message d'un coup (un seul aller-retour), puis on les garde (Active Storage).
class AttachmentCache
  def initialize(message)
    @message = message
  end

  def blob(index)
    cached(index) || (fill! && cached(index))
  end

  # Une image intégrée, par son Content-ID. Les messages importés avant les Content-ID les gagnent au passage.
  def inline_blob(content_id)
    index = index_for(content_id) || (fill! && index_for(content_id))
    blob(index) if index
  end

  private

  def cached(index)
    @message.attachment_files.find { |file| file.blob.metadata["index"] == index }&.blob
  end

  def index_for(content_id)
    @message.attachments.find { |attachment| attachment["content_id"] == content_id }&.dig("index")
  end

  # Verrou sur le message : plusieurs vignettes demandées en même temps ne rapatrient qu'une fois.
  def fill!
    @message.with_lock do
      @message.attachment_files.reload
      next if @message.attachment_files.any?

      parser = MessageParser.new(RawMessageFetcher.fetch(@message))
      parser.attachments.each do |attachment|
        @message.attachment_files.attach(io: StringIO.new(parser.attachment_data(attachment["index"]).to_s),
          filename: attachment["filename"], content_type: attachment["content_type"], metadata: { "index" => attachment["index"] })
      end
      @message.update!(attachments: parser.attachments, has_attachments: parser.attachments.any?)
    end
    @message.attachment_files.reload
    true
  end
end
