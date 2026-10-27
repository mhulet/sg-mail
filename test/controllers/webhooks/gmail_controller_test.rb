require "test_helper"

class Webhooks::GmailControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["GMAIL_PUBSUB_TOKEN"] = "secret"
    @mailbox = with_account(accounts(:semisto)) { Mailbox.create!(provider: "gmail", address: "formations@semisto.org") }
  end

  teardown { ENV.delete("GMAIL_PUBSUB_TOKEN") }

  def notify(token:, address: "Formations@semisto.org")
    data = [ { emailAddress: address, historyId: 42 }.to_json ].pack("m0")
    post "/webhooks/gmail?token=#{token}", params: { message: { data: data } }, as: :json
  end

  test "refuses a call without the secret" do
    assert_no_enqueued_jobs { notify(token: "wrong") }
    assert_response :unauthorized
  end

  test "queues a sync of the mailbox, under its account" do
    with_restricted_database_role { notify(token: "secret") }

    assert_response :no_content
    job = enqueued_jobs.sole
    assert_equal SyncMailboxJob, job[:job]
    assert_equal @mailbox.to_global_id.to_s, job[:args].first["_aj_globalid"]
    assert_equal accounts(:semisto).to_global_id.to_s, job["current_tenant"] || job[:current_tenant]
  end

  test "ignores an unknown address" do
    assert_no_enqueued_jobs { notify(token: "secret", address: "inconnu@example.org") }
    assert_response :no_content
  end
end
