# Contrôleurs sous /:account_id : l'utilisateur doit être membre du client, qui devient le client courant
# (filtre acts_as_tenant + Row Level Security, voir Tenancy).
module AccountScoped
  extend ActiveSupport::Concern

  included do
    around_action :scope_to_account
    helper_method :current_account, :current_membership
  end

  private

  def scope_to_account(&block)
    Current.membership = Current.user.memberships.includes(:account).find_by(account_id: requested_account_id)
    return redirect_to(accounts_path(account_id: nil), alert: "Ce client n'existe pas ou tu n'en fais pas partie.") unless Current.membership

    cookies.permanent[:last_account_id] = Current.account.id
    Tenancy.with_account(Current.account, &block)
  end

  def requested_account_id = params[:account_id]

  def current_account = Current.account
  def current_membership = Current.membership

  def require_admin
    redirect_to account_root_path, alert: "Réservé aux admins du client." unless Current.membership.admin?
  end
end
