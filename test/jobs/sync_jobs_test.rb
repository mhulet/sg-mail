require "test_helper"

class SyncJobsTest < ActiveJob::TestCase
  # Remplace la vraie synchro le temps d'un test et note sous quel client elle tourne.
  module RecordSync
    def sync!
      return super unless (synced = Thread.current[:recorded_syncs])

      synced << [ ActsAsTenant.current_tenant, address ]
    end
  end
  Mailbox.prepend(RecordSync)

  setup do
    @semisto = accounts(:semisto)
    @silvea = accounts(:silvea)
    @mailboxes = [ [ @semisto, "formations@semisto.org" ], [ @silvea, "contact@silvea.be" ] ].map do |account, address|
      with_account(account) { Mailbox.create!(provider: "imap", address: address) }
    end
    Thread.current[:recorded_syncs] = []
  end

  teardown { Thread.current[:recorded_syncs] = nil }

  test "the recurring job queues one sync per mailbox, each under its account" do
    with_restricted_database_role do
      perform_enqueued_jobs { SyncAllMailboxesJob.perform_now }
    end

    assert_equal [ [ @silvea, "contact@silvea.be" ], [ @semisto, "formations@semisto.org" ] ],
      Thread.current[:recorded_syncs].sort_by(&:last)
  end

  test "a sync job enqueued from a request finds its mailbox under row level security" do
    with_account(@semisto) { SyncMailboxJob.perform_later(@mailboxes.first) }

    with_restricted_database_role { perform_enqueued_jobs }

    assert_equal [ [ @semisto, "formations@semisto.org" ] ], Thread.current[:recorded_syncs]
  end
end
