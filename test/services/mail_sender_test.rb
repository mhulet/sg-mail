require "test_helper"

class MailSenderTest < ActiveSupport::TestCase
  class FakeGmail
    attr_reader :sent
    def send_user_message(user_id, message) = (@sent = [ user_id, message ])
  end

  class FakeSmtp
    attr_reader :sent, :starttls
    def port = 587
    def enable_starttls_auto = @starttls = true
    def start(*) = yield(self)
    def send_message(raw, from, recipients) = (@sent = [ raw, from, recipients ])
  end

  class FakeImap
    attr_reader :appended
    def append(folder, raw, flags, _date) = (@appended = [ folder, raw, flags ])
    def logout = nil
    def disconnect = nil
  end

  setup do
    ActsAsTenant.current_tenant = accounts(:semisto)
    @gmail = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
    @imap = Mailbox.create!(provider: "imap", address: "michael@semisto.org",
      credentials: { "host" => "mail.example.org", "username" => "michael", "password" => "secret" })
    @imap.mail_folders.create!(name: "INBOX")
    @imap.mail_folders.create!(name: "Sent")
    [ @gmail, @imap ].each { |mailbox| mailbox.grant!(users(:michael), "manage") }
    @source = @gmail.messages.create!(provider_uid: "g1", thread_key: "thread-1", message_id_header: "abc@example.org",
      subject: "Inscription", from_address: "anne@example.org", sent_at: 1.day.ago, body_text: "Bonjour")
    Conversation.rebuild_for(@gmail)
  end

  test "a Gmail reply joins its thread with the right headers" do
    draft = Draft.build_from(@source.reload, kind: "reply", user: users(:michael))
    draft.body = "Merci !\n\n#{draft.body}"
    gmail = FakeGmail.new
    MailSender.new(draft, gmail_service: gmail).deliver

    user_id, message = gmail.sent
    assert_equal "me", user_id
    assert_equal "thread-1", message.thread_id
    mail = Mail.new(message.raw)
    assert_equal [ "anne@example.org" ], mail.to
    assert_equal "Michael <formations@semisto.org>", mail[:from].value
    assert_equal "abc@example.org", mail.in_reply_to
    assert_includes mail.body.decoded, "Merci !"
  end

  test "an IMAP message goes out by SMTP and is copied to Sent" do
    draft = Draft.new(kind: "new", user: users(:michael), mailbox: @imap, to_list: "lea@example.org", bcc_list: "paul@example.org", subject: "Coucou", body: "Salut")
    smtp = FakeSmtp.new
    imap = FakeImap.new
    MailSender.new(draft, smtp: smtp, imap_connector: ->(_credentials) { imap }).deliver

    raw, from, recipients = smtp.sent
    assert_equal "michael@semisto.org", from
    assert_equal [ "lea@example.org", "paul@example.org" ], recipients
    assert smtp.starttls
    assert_nil Mail.new(raw).bcc # Cci jamais dans les en-têtes envoyés
    assert_equal [ "Sent", [ :Seen ] ], imap.appended.values_at(0, 2)
  end

  test "refuses a message without recipient" do
    draft = Draft.new(kind: "new", user: users(:michael), mailbox: @gmail, subject: "Vide")
    assert_raises(MailSender::Error) { MailSender.new(draft, gmail_service: FakeGmail.new).deliver }
  end
end
