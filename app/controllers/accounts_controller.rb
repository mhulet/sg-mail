class AccountsController < ApplicationController
  before_action :require_staff, only: %i[new create destroy]

  # Choix du client ; on y va directement s'il n'y en a qu'un. L'équipe Super Génial voit aussi tous les clients.
  def index
    @accounts = Current.user.accounts.order(:name)
    @all_accounts = Account.order(:name) if Current.user.staff?
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

  # Suppression complète d'un client, à sa demande (cadrage §4.2). Il faut retaper son nom.
  def destroy
    account = Account.find(params[:id])
    if params[:confirmation].to_s.strip == account.name
      account.purge!
      redirect_to accounts_path, notice: "Client « #{account.name} » supprimé, avec toutes ses données."
    else
      redirect_to accounts_path, alert: "Pour supprimer « #{account.name} », retape son nom exactement."
    end
  end

  private

  def require_staff
    redirect_to accounts_path, alert: "Réservé à l'équipe Super Génial." unless Current.user.staff?
  end
end
