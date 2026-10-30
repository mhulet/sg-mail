# « Répondre à la suite », comme Focus & Reply chez Hey : tous les fils de « Répondre plus tard » sur une seule page,
# chacun avec son dernier message et une réponse à écrire juste en dessous. Une réponse envoyée retire le fil de la pile.
class FocusRepliesController < ApplicationController
  include AccountScoped
  LIMIT = 30

  def show
    @conversations = Conversation.accessible_by(Current.user).in_stack_for(Current.user, "reply_later").one_per_email
      .includes(:mailbox).reorder(last_message_at: :asc, id: :asc).limit(LIMIT).to_a
    sendable = Mailbox.where(id: MailboxAccess.where(user: Current.user, level: %w[send manage]).select(:mailbox_id)).by_display_name.to_a
    @mailboxes = sendable
    @replies = @conversations.to_h do |conversation|
      message = conversation.messages.where.not(sent_at: nil).order(:sent_at).last || conversation.messages.last
      mailbox = sendable.find { |m| m.id == conversation.mailbox_id } || sendable.first
      [ conversation, [ message, (Draft.build_from(message, kind: "reply", user: Current.user, mailbox: mailbox) if message && mailbox) ] ]
    end
  end
end
