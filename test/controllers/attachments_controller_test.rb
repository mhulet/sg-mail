require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    raw = @raw = file_fixture("latin1_html_with_attachment.eml").binread
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @mailbox.grant!(users(:mohammad), "read")
      @message = @mailbox.messages.create!(provider_uid: "a", thread_key: "t1", sent_at: 1.day.ago, **MessageParser.parse(raw).except(:attachments), has_attachments: true)
      Conversation.rebuild_for(@mailbox)
    end
    RawMessageFetcher.singleton_class.alias_method(:original_fetch, :fetch)
    RawMessageFetcher.define_singleton_method(:fetch) { |_message| raw }
    sign_in_as users(:mohammad)
  end

  teardown { RawMessageFetcher.singleton_class.alias_method(:fetch, :original_fetch) }

  test "lists the attachments of an old message on demand, then downloads one" do
    post message_attachments_path(@message, account_id: @semisto.id)
    attachment = @message.reload.attachments.first
    assert attachment["filename"].present?

    get message_attachment_path(@message, attachment["index"], account_id: @semisto.id)
    assert_response :success
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
    assert_equal attachment["size"], response.body.bytesize
  end

  test "someone without access to the mailbox gets nothing" do
    sign_in_as users(:michael)
    get message_attachment_path(@message, 0, account_id: @semisto.id)
    assert_response :not_found
  end
end
