class SyncMailboxJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(mailbox) { mailbox } if respond_to?(:limits_concurrency)

  def perform(mailbox)
    mailbox.sync!
  end
end
