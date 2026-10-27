class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Les routes sous /:account_id reprennent le client courant.
  # Pour une route hors client, passer account_id: nil, sinon il s'ajoute en paramètre (?account_id=…).
  def default_url_options
    Current.account ? { account_id: Current.account.id } : {}
  end
end
