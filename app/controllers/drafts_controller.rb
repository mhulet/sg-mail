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

  # « Annuler » juste après l'envoi, ou un envoi prévu qu'on reprend : le message redevient un brouillon.
  def cancel
    draft = Draft.where(user: Current.user).find(params[:id])
    if draft.cancel_sending!
      redirect_to edit_draft_path(draft), notice: "Envoi annulé : le message est redevenu un brouillon."
    else
      redirect_back_or_to drafts_path, alert: "Trop tard : le message est déjà parti."
    end
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

  # « Envoyer plus tard » : un des choix proposés (une heure ISO 8601), ou l'heure saisie (« custom »).
  def scheduled_time
    value = params[:send_later].to_s
    value = params[:send_at].to_s if value == "custom"
    Time.zone.parse(value) if value.present?
  rescue ArgumentError
    nil
  end

  def save_and_maybe_send
    sending = params[:send].present? || params[:send_later].present?
    send_at = scheduled_time
    if params[:send_later].present? && (send_at.nil? || send_at.past?)
      @draft.errors.add(:base, "Choisis une heure d'envoi à venir.")
      return render(@draft.new_record? ? :new : :edit, status: :unprocessable_entity)
    end
    if @draft.save
      if sending
        @draft.schedule!(send_at)
        return redirect_to(drafts_path, notice: "Envoi prévu #{helpers.send_time_label(send_at)}.") if send_at

        flash[:cancel_send] = @draft.id
        flourish("sent")
        # Depuis « Répondre à la suite » : le fil quitte la pile tout de suite, et on passe au suivant.
        if params[:focus].present? && @draft.conversation
          @draft.conversation.put_in_stack_for!(Current.user, "reply_later", on: false)
          return redirect_to(focus_reply_path, notice: "Envoi depuis #{@draft.mailbox.display_name} dans #{Draft::UNDO_DELAY.to_i} s.")
        end
        redirect_to(@draft.conversation ? conversation_path(@draft.conversation) : drafts_path, notice: "Envoi depuis #{@draft.mailbox.display_name} dans #{Draft::UNDO_DELAY.to_i} s.")
      else
        redirect_to edit_draft_path(@draft), notice: "Brouillon enregistré."
      end
    else
      render(@draft.new_record? ? :new : :edit, status: :unprocessable_entity)
    end
  end
end
