# Rédiger, répondre, transférer : un brouillon qu'on enregistre ou qu'on envoie.
class DraftsController < ApplicationController
  include AccountScoped
  before_action :set_sendable_mailboxes
  before_action :set_draft, only: %i[edit update destroy]

  def index
    @drafts = Draft.where(user: Current.user).includes(:mailbox).order(updated_at: :desc).limit(100)
  end

  def new
    return redirect_to(account_root_path, alert: "Aucune boîte ne t'autorise à envoyer.") if @mailboxes.empty?

    if params[:message_id].present?
      message = Message.where(mailbox: Mailbox.accessible_by(Current.user)).find(params[:message_id])
      mailbox = @mailboxes.find { |m| m.id == message.mailbox_id } || @mailboxes.first
      @draft = Draft.build_from(message, kind: params[:kind].presence_in(Draft::KINDS) || "reply", user: Current.user, mailbox: mailbox)
    else
      @draft = Draft.start(user: Current.user, mailbox: @mailboxes.first)
    end
  end

  def create
    @draft = Draft.new(draft_params.merge(user: Current.user))
    @draft.source_message = Message.where(mailbox: Mailbox.accessible_by(Current.user)).find_by(id: params.dig(:draft, :source_message_id))
    @draft.conversation = @draft.source_message&.conversation
    save_and_maybe_send
  end

  def edit
  end

  def update
    @draft.assign_attributes(draft_params)
    save_and_maybe_send
  end

  def destroy
    @draft.destroy!
    redirect_to drafts_path, notice: "Brouillon supprimé."
  end

  private

  def set_sendable_mailboxes
    @mailboxes = Mailbox.where(id: MailboxAccess.where(user: Current.user, level: %w[send manage]).select(:mailbox_id)).by_display_name.to_a
  end

  def set_draft
    @draft = Draft.where(user: Current.user).editable.find(params[:id])
  end

  def draft_params
    params.expect(draft: %i[mailbox_id kind to_list cc_list bcc_list subject body]).tap do |permitted|
      if permitted.key?(:mailbox_id) && @mailboxes.none? { |m| m.id == permitted[:mailbox_id].to_i }
        permitted[:mailbox_id] = nil
      end
    end
  end

  def save_and_maybe_send
    sending = params[:send].present?
    @draft.status = "sending" if sending
    if @draft.save
      if sending
        SendDraftJob.perform_later(@draft)
        redirect_to(@draft.conversation ? conversation_path(@draft.conversation) : drafts_path, notice: "Envoi en cours depuis #{@draft.mailbox.display_name}.")
      else
        redirect_to edit_draft_path(@draft), notice: "Brouillon enregistré."
      end
    else
      @draft.status = "draft"
      render(@draft.new_record? ? :new : :edit, status: :unprocessable_entity)
    end
  end
end
