class Api::V1::ScreeningsController < Api::V1::BaseController
  # Le Screener : expéditeurs en attente de ma décision, et ceux que j'ai bloqués.
  def index
    render json: {
      pending: actions.screener(limit: params[:limit] || 100).map { |conversation| serializer.screener_entry(conversation) },
      blocked: actions.blocked_senders.map { |screening| serializer.screening(screening) }
    }
  end

  # Paramètres : address, decision (accepted ou blocked).
  def create
    render json: { screening: serializer.screening(actions.screen(params.require(:address), params.require(:decision))) }
  end
end
