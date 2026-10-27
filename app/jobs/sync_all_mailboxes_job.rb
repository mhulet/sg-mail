# Lance la synchro de chaque boîte, tous clients confondus (tâche récurrente, voir config/recurring.yml).
class SyncAllMailboxesJob < ApplicationJob
  queue_as :default

  def perform
    Tenancy.across_accounts do
      Mailbox.includes(:account).find_each do |mailbox|
        Tenancy.with_account(mailbox.account) { SyncMailboxJob.perform_later(mailbox) }
      end
    end
  end
end
