require "test_helper"

class GmailWatchTest < ActiveSupport::TestCase
  class FakeService
    attr_reader :requests
    def initialize = @requests = []

    def watch_user(user_id, request)
      @requests << [ user_id, request.topic_name ]
      Google::Apis::GmailV1::WatchResponse.new(expiration: 7.days.from_now.to_i * 1000, history_id: 1)
    end
  end

  setup do
    ActsAsTenant.current_tenant = accounts(:semisto)
    @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
    @service = FakeService.new
  end

  teardown { ENV.delete("GMAIL_PUBSUB_TOPIC") }

  test "does nothing without a Pub/Sub topic" do
    GmailWatch.new(@mailbox, service: @service).renew_if_needed
    assert_empty @service.requests
  end

  test "watches the mailbox, then only renews it close to expiry" do
    ENV["GMAIL_PUBSUB_TOPIC"] = "projects/sg-mail/topics/gmail"

    GmailWatch.new(@mailbox, service: @service).renew_if_needed
    assert_equal [ [ "me", "projects/sg-mail/topics/gmail" ] ], @service.requests
    assert_in_delta 7.days.from_now.to_i, @mailbox.reload.sync_state["watch_expires_at"], 5

    GmailWatch.new(@mailbox, service: @service).renew_if_needed
    assert_equal 1, @service.requests.size

    @mailbox.update!(sync_state: { "watch_expires_at" => 12.hours.from_now.to_i })
    GmailWatch.new(@mailbox, service: @service).renew_if_needed
    assert_equal 2, @service.requests.size
  end
end
