class MailboxesController < ApplicationController
  include AccountScoped
  before_action :set_mailbox, only: %i[show sync destroy]
  before_action :require_manage_access, only: :destroy

  # Seules les boîtes auxquelles on a accès : une boîte perso reste privée, même pour les admins.
  def index
    @mailboxes = Mailbox.accessible_by(Current.user).includes(:accesses).order(:address)
  end

  def show
  end

  def new
    @mailbox = Mailbox.new(provider: "imap")
  end

  # Connexion d'une boîte IMAP : on vérifie l'identification avant d'enregistrer.
  def create
    credentials = params.require(:imap).permit(:host, :port, :username, :password, :ssl).to_h
    credentials["ssl"] = credentials["ssl"] != "0"
    @mailbox = Mailbox.new(provider: "imap", address: params.dig(:imap, :address).presence || credentials["username"], credentials: credentials, connected_by: Current.user)

    ImapSync.connect(credentials).tap { |imap| imap.logout rescue nil; imap.disconnect rescue nil }
    Mailbox.transaction do
      @mailbox.save!
      @mailbox.grant!(Current.user, "manage")
    end
    SyncMailboxJob.perform_later(@mailbox)
    redirect_to @mailbox, notice: "#{@mailbox.address} connectée. Import lancé."
  rescue Net::IMAP::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Connexion IMAP impossible : #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def sync
    SyncMailboxJob.perform_later(@mailbox)
    redirect_to @mailbox, notice: "Synchronisation lancée."
  end

  def destroy
    @mailbox.destroy!
    redirect_to mailboxes_path, notice: "Boîte déconnectée."
  end

  private

  def set_mailbox
    @mailbox = Mailbox.accessible_by(Current.user).find(params[:id])
    @access = @mailbox.access_for(Current.user)
  end

  def require_manage_access
    redirect_to @mailbox, alert: "Il faut le droit de gestion sur cette boîte." unless @access.can_manage?
  end
end
