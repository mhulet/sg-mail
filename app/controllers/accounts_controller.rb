class AccountsController < ApplicationController
  before_action :require_staff, only: %i[new create]

  # Choix du client ; on y va directement s'il n'y en a qu'un.
  def index
    @accounts = Current.user.accounts.order(:name)
    redirect_to account_root_path(account_id: @accounts.first.id) if @accounts.one? && !Current.user.staff?
  end

  def new
    @account = Account.new
  end

  # L'équipe Super Génial crée le client et invite son premier admin, sans en devenir membre.
  def create
    @account = Account.new(name: params.dig(:account, :name))
    @invitation = @account.invitations.build(email_address: params.dig(:account, :admin_email), role: "admin", invited_by: Current.user)

    if @account.valid? & @invitation.valid?
      @account.save!
      InvitationMailer.invite(@invitation).deliver_later
      redirect_to accounts_path, notice: "Client « #{@account.name} » créé. Invitation envoyée à #{@invitation.email_address} : #{invitation_acceptance_url(@invitation.token)}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_staff
    redirect_to accounts_path, alert: "Réservé à l'équipe Super Génial." unless Current.user.staff?
  end
end
