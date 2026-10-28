# Le Screener : les nouveaux expéditeurs attendent ici qu'on les accepte ou qu'on les bloque.
# Chaque personne décide pour elle seule.
class ScreeningsController < ApplicationController
  include AccountScoped

  def index
    @pending = Conversation.screener_for(Current.user).to_a
    @blocked = Screening.where(user: Current.user, decision: "blocked").order(updated_at: :desc)
  end

  def create
    screening = Screening.decide!(Current.user, params.require(:address), params.require(:decision))
    notice = screening.decision == "accepted" ? "#{screening.address} arrive désormais dans ta réception." : "#{screening.address} est bloqué : ses emails restent hors de ta réception."
    redirect_back_or_to screenings_path, notice: notice
  rescue ArgumentError
    redirect_back_or_to screenings_path, alert: "Décision inconnue."
  end
end
