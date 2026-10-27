# Écoute l'INBOX d'une boîte IMAP en IDLE et prévient dès que le serveur signale un changement
# (nouveau message ou suppression). La synchro elle-même reste celle d'ImapSync.
class ImapIdle
  # On relance IDLE régulièrement : la RFC 2177 demande moins de 29 minutes, et c'est l'occasion
  # de vérifier qu'on doit continuer.
  IDLE_TIMEOUT = 5 * 60
  CHANGES = %w[EXISTS EXPUNGE].freeze

  def initialize(credentials, on_change:, connector: ImapSync.method(:connect))
    @credentials = credentials
    @on_change = on_change
    @connector = connector
  end

  def run(stop: -> { false })
    imap = @connector.call(@credentials)
    imap.examine("INBOX")
    @on_change.call # rattrape ce qui est arrivé pendant qu'on n'écoutait pas

    until stop.call
      changed = false
      imap.idle(IDLE_TIMEOUT) do |response|
        if response.is_a?(Net::IMAP::UntaggedResponse) && CHANGES.include?(response.name)
          changed = true
          imap.idle_done
        end
      end
      @on_change.call if changed
    end
  ensure
    imap&.logout rescue nil
    imap&.disconnect rescue nil
  end
end
