# Afficher une pièce jointe dans SG Mail plutôt que la télécharger : seulement des images et des PDF, servis
# avec leur type vérifié (jamais celui annoncé par l'expéditeur seul) et sans « devinette » du navigateur.
# Un fichier HTML ou SVG reste toujours un téléchargement : il ne doit jamais s'ouvrir sur le domaine de SG Mail.
module AttachmentServing
  VIEWABLE_IMAGES = %w[image/png image/jpeg image/gif image/webp].freeze
  VIEWABLE_TYPES = (VIEWABLE_IMAGES + %w[application/pdf]).freeze
  THUMBNAIL_SIZE = [ 480, 480 ].freeze

  private

  def viewable?(blob) = blob.content_type.in?(VIEWABLE_TYPES)

  def serve_inline(blob)
    response.headers["X-Content-Type-Options"] = "nosniff"
    # Une image ne peut rien exécuter ; le bac à sable le garantit même ouverte seule dans un onglet.
    # (Le lecteur PDF des navigateurs refuse de s'afficher en bac à sable : les PDF n'ont que le type forcé.)
    response.headers["Content-Security-Policy"] = "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; sandbox" if blob.content_type.in?(VIEWABLE_IMAGES)
    expires_in 1.day, private: true
    send_data blob.download, filename: blob.filename.to_s, type: blob.content_type, disposition: "inline"
  end

  def serve_thumbnail(blob)
    return head(:not_found) unless blob.representable?

    data = (blob.variable? ? blob.variant(resize_to_limit: THUMBNAIL_SIZE) : blob.preview(resize_to_limit: THUMBNAIL_SIZE)).processed.download
    type = Marcel::MimeType.for(StringIO.new(data))
    return head(:not_found) unless type.in?(VIEWABLE_IMAGES)

    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    expires_in 1.week, private: true
    send_data data, type: type, disposition: "inline"
  rescue LoadError, StandardError => error
    # libvips ou poppler absents du serveur, image abîmée… : la carte garde son icône.
    Rails.logger.info("Vignette impossible pour la pièce jointe #{blob.id} : #{error.class}")
    head :not_found
  end
end
