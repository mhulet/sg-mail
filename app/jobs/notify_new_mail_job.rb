class NotifyNewMailJob < ApplicationJob
  queue_as :default

  def perform(mailbox, since)
    NewMailNotifier.new(mailbox, since: since).call
  end
end
