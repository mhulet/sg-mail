class MailboxesController < ApplicationController
  def index
    @mailboxes = Mailbox.order(:address)
  end

  def show
    @mailbox = Mailbox.find(params[:id])
    @messages = @mailbox.messages.recent.limit(100)
  end

  def new
    @mailbox = Mailbox.new(provider: "imap")
  end

  # Connexion d'une boîte IMAP : on vérifie l'identification avant d'enregistrer.
  def create
    credentials = params.require(:imap).permit(:host, :port, :username, :password, :ssl).to_h
    credentials["ssl"] = credentials["ssl"] != "0"
    @mailbox = Mailbox.new(provider: "imap", address: params.dig(:imap, :address).presence || credentials["username"], credentials: credentials)

    ImapSync.connect(credentials).tap { |imap| imap.logout rescue nil; imap.disconnect rescue nil }
    @mailbox.save!
    SyncMailboxJob.perform_later(@mailbox)
    redirect_to @mailbox, notice: "#{@mailbox.address} connectée. Import lancé."
  rescue Net::IMAP::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Connexion IMAP impossible : #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def sync
    mailbox = Mailbox.find(params[:id])
    SyncMailboxJob.perform_later(mailbox)
    redirect_to mailbox, notice: "Synchronisation lancée."
  end

  def destroy
    Mailbox.find(params[:id]).destroy!
    redirect_to mailboxes_path, notice: "Boîte déconnectée."
  end
end
