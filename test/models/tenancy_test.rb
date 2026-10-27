require "test_helper"

class TenancyTest < ActiveSupport::TestCase
  setup do
    @semisto = accounts(:semisto)
    @silvea = accounts(:silvea)
    with_account(@semisto) { @semisto_mailbox = Mailbox.create!(provider: "imap", address: "formations@semisto.org") }
    with_account(@silvea) { @silvea_mailbox = Mailbox.create!(provider: "imap", address: "contact@silvea.be") }
  end

  test "acts_as_tenant refuses to query mailboxes without an account" do
    assert_raises(ActsAsTenant::Errors::NoTenantSet) { Mailbox.count }
  end

  test "row level security only returns the current account's rows, even unscoped" do
    with_restricted_database_role do
      with_account(@semisto) do
        assert_equal [ @semisto_mailbox.id ], Mailbox.unscoped.pluck(:id)
        assert_nil Mailbox.unscoped.find_by(id: @silvea_mailbox.id)
      end
    end
  end

  test "row level security returns nothing when no account is set" do
    with_restricted_database_role do
      ActsAsTenant.without_tenant { assert_equal 0, Mailbox.count }
    end
  end

  test "row level security refuses to write a row for another account" do
    with_restricted_database_role do
      with_account(@semisto) do
        error = assert_raises(ActiveRecord::StatementInvalid) do
          Mailbox.transaction(requires_new: true) do
            Mailbox.unscoped.insert_all!([ { account_id: @silvea.id, provider: "imap", address: "intrus@example.org" } ])
          end
        end
        assert_match "row-level security", error.message
      end
    end
  end

  test "across_accounts sees every account, then closes again" do
    with_restricted_database_role do
      Tenancy.across_accounts { assert_equal 2, Mailbox.count }
      ActsAsTenant.without_tenant { assert_equal 0, Mailbox.count }
    end
  end

  test "with_account inside across_accounts sticks to that account" do
    with_restricted_database_role do
      Tenancy.across_accounts do
        with_account(@silvea) { assert_equal [ @silvea_mailbox.id ], Mailbox.unscoped.pluck(:id) }
      end
    end
  end

  test "a connection checked out of the pool starts without account" do
    connection = ActiveRecord::Base.lease_connection
    Tenancy.set(connection, Tenancy::ACCOUNT_SETTING, @semisto.id.to_s)
    Tenancy.reset(connection)
    assert_equal "", connection.select_value("SELECT current_setting('sg_mail.account_id', true)")
  end

  test "messages and folders take their mailbox's account" do
    with_account(@semisto) do
      folder = @semisto_mailbox.mail_folders.create!(name: "INBOX")
      message = @semisto_mailbox.messages.create!(provider_uid: "1", mail_folder: folder)
      assert_equal [ @semisto.id ] * 2, [ folder.account_id, message.account_id ]
    end
  end
end
