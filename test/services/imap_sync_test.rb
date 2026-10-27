require "test_helper"

# Test de bout en bout contre un vrai serveur IMAP (Dovecot local par exemple) :
#   IMAP_TEST_HOST=127.0.0.1 IMAP_TEST_PORT=1143 IMAP_TEST_USER=… IMAP_TEST_PASSWORD=… bin/rails test
class ImapSyncTest < ActiveSupport::TestCase
  setup do
    skip "IMAP_TEST_HOST non défini" if ENV["IMAP_TEST_HOST"].blank?

    @credentials = {
      "host" => ENV["IMAP_TEST_HOST"], "port" => ENV.fetch("IMAP_TEST_PORT", 993),
      "username" => ENV["IMAP_TEST_USER"], "password" => ENV["IMAP_TEST_PASSWORD"],
      "ssl" => ENV["IMAP_TEST_SSL"] != "0"
    }
    @imap = ImapSync.connect(@credentials)
    %w[INBOX Sent].each do |folder|
      @imap.select(folder)
      uids = @imap.uid_search([ "ALL" ])
      @imap.uid_store(uids, "+FLAGS", [ :Deleted ]) if uids.any?
      @imap.expunge
    end
    @mailbox = Mailbox.create!(provider: "imap", address: "test@example.org", credentials: @credentials)
  end

  teardown { @imap&.disconnect }

  test "importe, suit les nouveaux messages et les suppressions, sans marquer comme lu" do
    append("INBOX", file_fixture("latin1_html_with_attachment.eml").binread)
    append("INBOX", mail("Premier", "root-1@example.org"))
    append("Sent", mail("Envoyé", "sent-1@example.org"))

    ImapSync.new(@mailbox).call
    assert_equal 3, @mailbox.messages.count
    assert_equal %w[INBOX Sent], @mailbox.mail_folders.order(:name).pluck(:name)
    assert_equal 2, @mailbox.messages.where(thread_key: "root-1@example.org").count

    @imap.examine("INBOX")
    assert @imap.uid_search([ "UNSEEN" ]).size == 2, "la synchro ne doit pas poser \\Seen"

    append("INBOX", mail("Deuxième", "root-2@example.org"))
    @imap.select("INBOX")
    first_uid = @imap.uid_search([ "HEADER", "Message-ID", "root-1@example.org" ]).first
    @imap.uid_store(first_uid, "+FLAGS", [ :Deleted ])
    @imap.expunge

    ImapSync.new(@mailbox).call
    assert_equal %w[Deuxième Envoyé Inscription\ à\ la\ formation].sort, @mailbox.messages.pluck(:subject).sort
  end

  private

  def append(folder, raw)
    @imap.append(folder, raw.gsub(/\r?\n/, "\r\n"), [], Time.current)
  end

  def mail(subject, message_id)
    "From: michael@example.org\nTo: test@example.org\nSubject: #{subject}\nMessage-ID: <#{message_id}>\nDate: #{Time.current.rfc2822}\n\nBonjour\n"
  end
end
