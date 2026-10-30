class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Une petite scène animée sur la page suivante, à côté du bandeau : la boîte qui avale le fil archivé,
  # le réveil de « Plus tard », l'avion en papier de l'envoi… (voir shared/_flourish).
  def flourish(kind, count: 1)
    flash[:flourish] = kind
    flash[:flourish_count] = count
  end

  # Les routes sous /:account_id reprennent le client courant.
  # Pour une route hors client, passer account_id: nil, sinon il s'ajoute en paramètre (?account_id=…).
  def default_url_options
    Current.account ? { account_id: Current.account.id } : {}
  end
end
