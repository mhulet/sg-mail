class ProviderArchiveJob < ApplicationJob
  queue_as :default
  retry_on Google::Apis::ServerError, Google::Apis::RateLimitError, wait: :polynomially_longer, attempts: 5

  # archive: true quand tout le monde a archivé le fil ; false quand quelqu'un le remet dans sa réception.
  def perform(conversation, archive:)
    if archive
      ProviderArchive.new(conversation).archive if conversation.in_inbox && conversation.archived_by_everyone?
    else
      ProviderArchive.new(conversation).unarchive unless conversation.in_inbox
    end
  end
end
