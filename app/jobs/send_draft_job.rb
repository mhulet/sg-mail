class SendDraftJob < ApplicationJob
  queue_as :default

  def perform(draft)
    # Un envoi programmé ne part qu'à son heure, et une seule fois : il a pu être annulé, ou reprogrammé
    # (un autre job attend alors la nouvelle heure).
    draft.with_lock do
      return unless draft.status == "sending" || (draft.scheduled? && draft.send_at <= 1.second.from_now)

      draft.update!(status: "sending")
    end

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
