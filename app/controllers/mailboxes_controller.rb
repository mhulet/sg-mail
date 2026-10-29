class MailboxesController < ApplicationController
  include AccountScoped
  before_action :set_mailbox, only: %i[show edit update sync preferences destroy]
  before_action :require_manage_access, only: %i[edit update destroy]

  # Seules les boîtes auxquelles on a accès : une boîte perso reste privée, même pour les admins.
  def index
    @mailboxes = Mailbox.accessible_by(Current.user).includes(:accesses).by_display_name
  end

  def show
  end

  def new
    @mailbox = Mailbox.new(provider: "imap")
  end

  # Connexion d'une boîte IMAP : on vérifie l'identification avant d'enregistrer.
  def create
    credentials = params.require(:imap).permit(:host, :port, :username, :password, :ssl, :smtp_host, :smtp_port).to_h
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

  def edit
  end

  # Réglages de la boîte, pour qui la gère : libellé et, pour une boîte IMAP, serveurs et identifiants.
  # De nouveaux identifiants IMAP sont testés avant d'être enregistrés.
  def update
    @mailbox.label = params.dig(:mailbox, :label)
    if @mailbox.imap? && params[:imap]
      credentials = @mailbox.imap_credentials_with(params.require(:imap).permit(*Mailbox::IMAP_SETTINGS))
      if credentials != @mailbox.credentials
        ImapSync.connect(credentials).tap { |imap| imap.logout rescue nil; imap.disconnect rescue nil }
        @mailbox.credentials = credentials
        @mailbox.last_sync_error = nil
        resync = true
      end
    end
    @mailbox.save!
    SyncMailboxJob.perform_later(@mailbox) if resync
    redirect_to @mailbox, notice: resync ? "Réglages enregistrés. Synchronisation relancée." : "Réglages enregistrés."
  rescue Net::IMAP::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    flash.now[:alert] = "Connexion IMAP impossible, rien n'a été changé : #{e.message}"
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  # Ma signature et mon nom d'expéditeur dans cette boîte.
  def preferences
    @access.update!(params.expect(mailbox_access: %i[sender_name signature]))
    redirect_to @mailbox, notice: "Signature enregistrée."
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
