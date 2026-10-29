require "test_helper"

class MailboxSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    @credentials = { "host" => "mail.example.org", "port" => "993", "username" => "formations", "password" => "secret", "ssl" => true, "smtp_host" => "", "smtp_port" => "587" }
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "imap", address: "formations@semisto.org", credentials: @credentials)
      @mailbox.grant!(users(:mohammad), "manage")
      @mailbox.grant!(users(:michael), "send")
      @other = Mailbox.create!(provider: "gmail", address: "michael@semisto.org")
      @other.grant!(users(:michael), "manage")
    end
    @connections = []
    connections = @connections
    fake_imap = Object.new.tap { |imap| def imap.logout = nil; def imap.disconnect = nil }
    ImapSync.singleton_class.alias_method(:original_connect, :connect)
    ImapSync.define_singleton_method(:connect) { |credentials| connections << credentials; fake_imap }
  end

  teardown do
    ImapSync.singleton_class.alias_method(:connect, :original_connect)
  end

  def reload(mailbox) = with_account(@semisto) { mailbox.reload }

  test "only managers reach the settings page" do
    sign_in_as users(:michael)
    get edit_mailbox_path(@mailbox, account_id: @semisto.id)
    assert_redirected_to mailbox_path(@mailbox, account_id: @semisto.id)
    patch mailbox_path(@mailbox, account_id: @semisto.id), params: { mailbox: { label: "Pirate" } }
    assert_nil reload(@mailbox).label
  end

  test "a label replaces the address in the sidebar, the lists and the compose form" do
    sign_in_as users(:mohammad)
    get edit_mailbox_path(@mailbox, account_id: @semisto.id)
    assert_response :success

    patch mailbox_path(@mailbox, account_id: @semisto.id), params: { mailbox: { label: "  Formations " } }
    assert_redirected_to mailbox_path(@mailbox, account_id: @semisto.id)
    assert_equal "Formations", reload(@mailbox).label
    assert_empty @connections, "no IMAP setting changed, nothing to test"

    sign_in_as users(:michael)
    get account_root_path(account_id: @semisto.id)
    assert_select ".sub-spaces .label", "Formations"
    assert_select ".sub-spaces a[title=?]", "formations@semisto.org"
    get new_draft_path(account_id: @semisto.id)
    assert_select "select[name='draft[mailbox_id]'] option", "Formations <formations@semisto.org>"
    get search_path(account_id: @semisto.id)
    assert_select "select[name=mailbox_id] option", "Formations"
  end

  test "a blank label falls back to the address" do
    with_account(@semisto) { @mailbox.update!(label: "Formations") }
    sign_in_as users(:mohammad)
    patch mailbox_path(@mailbox, account_id: @semisto.id), params: { mailbox: { label: " " } }
    assert_nil reload(@mailbox).label
    assert_equal "formations@semisto.org", reload(@mailbox).display_name
  end

  test "new IMAP settings are tested, saved, and keep the password when left blank" do
    sign_in_as users(:mohammad)
    assert_enqueued_with(job: SyncMailboxJob) do
      patch mailbox_path(@mailbox, account_id: @semisto.id),
        params: { mailbox: { label: "" }, imap: { host: "imap.infomaniak.com", port: "993", username: "formations", password: "", ssl: "1", smtp_host: "", smtp_port: "587" } }
    end
    credentials = reload(@mailbox).credentials
    assert_equal "imap.infomaniak.com", credentials["host"]
    assert_equal "secret", credentials["password"]
    assert_equal [ credentials ], @connections
  end

  test "IMAP settings that do not connect change nothing" do
    ImapSync.define_singleton_method(:connect) { |_credentials| raise Net::IMAP::NoResponseError, Struct.new(:data).new(Struct.new(:text).new("Authentication failed")) }
    sign_in_as users(:mohammad)
    patch mailbox_path(@mailbox, account_id: @semisto.id),
      params: { mailbox: { label: "Formations" }, imap: { host: "mail.example.org", port: "993", username: "formations", password: "wrong", ssl: "1" } }
    assert_response :unprocessable_entity
    assert_equal @credentials, reload(@mailbox).credentials
    assert_nil reload(@mailbox).label
  end

  test "in: finds a mailbox by its label" do
    with_account(@semisto) do
      @mailbox.update!(label: "Academy")
      @mailbox.messages.create!(provider_uid: "1", subject: "Inscription", from_address: "anne@example.org")
      Conversation.rebuild_for(@mailbox)
    end
    search = with_account(@semisto) { MessageSearch.new(users(:michael), "in:academy").conversations.map(&:mailbox_id) }
    assert_equal [ @mailbox.id ], search.uniq
  end
end
