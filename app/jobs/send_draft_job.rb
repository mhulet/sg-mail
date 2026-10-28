class SendDraftJob < ApplicationJob
  queue_as :default

  def perform(draft)
    return unless draft.status == "sending"

    MailSender.new(draft).deliver
    draft.update!(status: "sent", sent_at: Time.current, error: nil)
    # Répondre sort le fil de « Répondre plus tard », pour la personne qui a répondu.
    ConversationState.where(conversation_id: draft.conversation_id, user_id: draft.user_id).update_all(reply_later_at: nil) if draft.conversation_id
    # Le message envoyé rejoint son fil à la synchro suivante, qu'on lance tout de suite.
    SyncMailboxJob.perform_later(draft.mailbox)
  rescue StandardError => e
    draft.update!(status: "failed", error: "#{e.class}: #{e.message}")
  end
end
