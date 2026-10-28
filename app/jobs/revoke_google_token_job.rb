# Une boîte Gmail retirée de SG Mail : on rend aussi l'accès chez Google (cadrage §4.2).
# Le jeton est révoqué, donc inutilisable, quand le job (et ses arguments) est encore en base.
class RevokeGoogleTokenJob < ApplicationJob
  queue_as :default
  retry_on Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 5

  def perform(token)
    Net::HTTP.post_form(URI("https://oauth2.googleapis.com/revoke"), token: token)
  end
end
