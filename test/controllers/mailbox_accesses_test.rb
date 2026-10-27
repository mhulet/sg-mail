require "test_helper"

class MailboxAccessesTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @personal = Mailbox.create!(provider: "imap", address: "mohammad@semisto.org", connected_by: users(:mohammad))
      @personal.grant!(users(:mohammad), "manage")
      @personal.messages.create!(provider_uid: "1", subject: "Perso")
      @shared = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @shared.grant!(users(:mohammad), "manage")
      @shared.grant!(users(:michael), "read")
    end
  end

  def access_level(user, mailbox) = with_account(@semisto) { mailbox.access_for(user)&.level }

  test "a personal mailbox stays private, even from the account's admins" do
    sign_in_as users(:michael)
    get mailboxes_path(account_id: @semisto.id)
    assert_select "a", "formations@semisto.org"
    assert_select "a", { text: "mohammad@semisto.org", count: 0 }

    get mailbox_path(@personal, account_id: @semisto.id)
    assert_response :not_found
    message = with_account(@semisto) { @personal.messages.first }
    get message_path(message, account_id: @semisto.id)
    assert_response :not_found
  end

  test "a manager shares a mailbox and changes access levels" do
    sign_in_as users(:mohammad)
    get mailbox_accesses_path(@personal, account_id: @semisto.id)
    assert_response :success

    patch mailbox_access_path(@personal, users(:michael), account_id: @semisto.id), params: { level: "send" }
    assert_equal "send", access_level(users(:michael), @personal)

    patch mailbox_access_path(@personal, users(:michael), account_id: @semisto.id), params: { level: "" }
    assert_nil access_level(users(:michael), @personal)
  end

  test "the last manager can neither leave nor be demoted" do
    sign_in_as users(:mohammad)
    patch mailbox_access_path(@personal, users(:mohammad), account_id: @semisto.id), params: { level: "read" }
    assert_equal "manage", access_level(users(:mohammad), @personal)
    patch mailbox_access_path(@personal, users(:mohammad), account_id: @semisto.id), params: { level: "" }
    assert_equal "manage", access_level(users(:mohammad), @personal)
  end

  test "only members of the account can be given access" do
    sign_in_as users(:mohammad)
    patch mailbox_access_path(@personal, users(:lea), account_id: @semisto.id), params: { level: "read" }
    assert_response :not_found
  end

  test "readers cannot manage access" do
    sign_in_as users(:michael)
    patch mailbox_access_path(@shared, users(:michael), account_id: @semisto.id), params: { level: "manage" }
    assert_equal "read", access_level(users(:michael), @shared)
  end

  test "leaving the account removes one's mailbox accesses" do
    sign_in_as users(:mohammad)
    with_account(@semisto) { @shared.grant!(users(:michael), "manage") }
    delete membership_path(memberships(:mohammad_semisto), account_id: @semisto.id)
    assert_nil access_level(users(:mohammad), @shared)
  end

  test "connecting an IMAP mailbox makes it a personal mailbox managed by its owner" do
    sign_in_as users(:michael)
    fake_imap = Object.new.tap { |imap| def imap.logout = nil; def imap.disconnect = nil }
    ImapSync.singleton_class.alias_method(:original_connect, :connect)
    ImapSync.define_singleton_method(:connect) { |_credentials| fake_imap }

    post mailboxes_path(account_id: @semisto.id), params: { imap: { address: "michael@semisto.org", host: "imap.example.org", port: 993, username: "michael", password: "secret" } }

    mailbox = with_account(@semisto) { Mailbox.find_by!(address: "michael@semisto.org") }
    assert_equal users(:michael), mailbox.connected_by
    assert_equal "manage", access_level(users(:michael), mailbox)
    assert_equal 1, with_account(@semisto) { mailbox.accesses.count }
  ensure
    ImapSync.singleton_class.alias_method(:connect, :original_connect)
  end
end
