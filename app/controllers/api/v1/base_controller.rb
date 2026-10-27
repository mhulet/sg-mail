# API JSON (/api/v1) : authentification par jeton personnel, dans le client du jeton.
# Mêmes droits que dans l'interface (voir MailActions).
class Api::V1::BaseController < ActionController::API
  around_action :authenticate

  rescue_from ActionController::ParameterMissing, ArgumentError do |error|
    render json: { error: "bad_request", message: error.message }, status: :bad_request
  end
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found" }, status: :not_found
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { error: "invalid", messages: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def authenticate(&block)
    Current.membership = BearerAuth.membership_for(request)
    return render(json: { error: "invalid_token" }, status: :unauthorized) unless Current.membership

    Tenancy.with_account(Current.account, &block)
  end

  def actions = @actions ||= MailActions.new(Current.user)
  def serializer = @serializer ||= ApiSerializer.new(user: Current.user, base_url: request.base_url)
end
