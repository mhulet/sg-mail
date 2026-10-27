require "test_helper"

class DraftTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = accounts(:semisto)
    @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
    @mailbox.grant!(users(:mohammad), "send")
    @message = @mailbox.messages.create!(provider_uid: "a", thread_key: "t1", subject: "Inscription",
      from_address: "anne@example.org", from_name: "Anne", to_addresses: [ "formations@semisto.org", "lea@example.org" ],
      cc_addresses: [ "Paul@example.org", "anne@example.org" ], sent_at: Time.zone.parse("2026-10-26 10:00"), body_text: "Bonjour,\nje m'inscris.")
  end

  def build(kind) = Draft.build_from(@message, kind: kind, user: users(:mohammad))

  test "a reply goes to the sender, quoting the message" do
    draft = build("reply")
    assert_equal [ "anne@example.org" ], draft.to_addresses
    assert_empty draft.cc_addresses
    assert_equal "Re: Inscription", draft.subject
    assert_includes draft.body, "Anne a écrit :\n> Bonjour,\n> je m'inscris."
  end

  test "reply all copies everyone but us and the sender" do
    assert_equal [ "lea@example.org", "Paul@example.org" ], build("reply_all").cc_addresses
  end

  test "a forward has no recipient yet and carries the original" do
    draft = build("forward")
    assert_empty draft.to_addresses
    assert_equal "Fwd: Inscription", draft.subject
    assert_includes draft.body, "De : Anne <anne@example.org>"
  end

  test "replying to a reply keeps a single Re:" do
    @message.subject = "RE: Inscription"
    assert_equal "RE: Inscription", build("reply").subject
  end

  test "addresses are validated and a reader cannot send" do
    draft = build("reply")
    draft.to_list = "anne@example.org, pas-une-adresse"
    assert_not draft.valid?

    draft.to_list = "anne@example.org"
    assert draft.valid?

    @mailbox.grant!(users(:mohammad), "read")
    assert_not draft.valid?
  end
end
