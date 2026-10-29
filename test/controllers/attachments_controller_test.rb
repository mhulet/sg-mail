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
    @fetches = 0
    fetches = -> { @fetches += 1 }
    raws = @raws = { @message.id => raw }
    RawMessageFetcher.singleton_class.alias_method(:original_fetch, :fetch)
    RawMessageFetcher.define_singleton_method(:fetch) { |message| fetches.call && raws.fetch(message.id) }
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

  test "fetches the attachments from the provider once, then serves them from the cache" do
    message = create_message(gallery_raw)
    get message_attachment_path(message, 1, account_id: @semisto.id)
    get message_attachment_path(message, 2, account_id: @semisto.id)
    get message_attachment_path(message, 1, account_id: @semisto.id)

    assert_response :success
    assert_equal 1, @fetches
    assert_equal file_fixture("pixel.png").binread, response.body
  end

  test "shows images and PDFs in the viewer, sandboxed, but always downloads anything else" do
    message = create_message(gallery_raw)

    get message_attachment_path(message, 1, view: 1, account_id: @semisto.id)
    assert_match(/\Ainline;/, response.headers["Content-Disposition"])
    assert_equal "image/png", response.media_type
    assert_includes response.headers["Content-Security-Policy"], "sandbox"

    get message_attachment_path(message, 2, view: 1, account_id: @semisto.id)
    assert_match(/\Ainline;/, response.headers["Content-Disposition"])
    assert_equal "application/pdf", response.media_type

    # Annoncé comme une image, mais c'est du HTML : jamais affiché sur le domaine de SG Mail.
    get message_attachment_path(message, 3, view: 1, account_id: @semisto.id)
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
  end

  test "makes a thumbnail of an image" do
    message = create_message(gallery_raw)
    get thumbnail_message_attachment_path(message, 1, account_id: @semisto.id)

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "downloads every attachment of a message as a zip, without the images of the body" do
    message = create_message(gallery_raw)
    get archive_message_attachments_path(message, account_id: @semisto.id)

    assert_response :success
    assert_equal "application/zip", response.media_type
    names = []
    Zip::InputStream.open(StringIO.new(response.body)) { |zip| while (entry = zip.get_next_entry) do names << entry.name end }
    assert_equal [ "photo.png", "programme.pdf", "photo (2).png" ], names
  end

  test "the thread shows images of the body through a signed address, and lists the other attachments as cards" do
    message = create_message(gallery_raw)
    get conversation_path(message.conversation_id, account_id: @semisto.id)

    assert_response :success
    assert_select "iframe.body[srcdoc*='/inline/']"
    assert_select ".attachment-card", 3
    assert_select ".attachment-card[data-family=pdf] a[data-viewer-kind=pdf]"
    assert_select "a[href*='archive']", text: "Tout télécharger (.zip)"
  end

  test "an image of the body opens without a session, through its signed address only" do
    message = create_message(gallery_raw)
    token = InlineImagesController.token_for(message, "logo@sg")
    sign_out

    get inline_image_path(token)
    assert_response :success
    assert_equal "image/png", response.media_type

    get inline_image_path(token.reverse)
    assert_response :not_found

    travel 2.days do
      get inline_image_path(token)
      assert_response :not_found
    end
  end

  private

  def create_message(raw)
    with_account(@semisto) do
      @mailbox.messages.create!(provider_uid: SecureRandom.hex(4), thread_key: SecureRandom.hex(4), sent_at: 1.hour.ago, **MessageParser.parse(raw)).tap do |message|
        Conversation.rebuild_for(@mailbox)
        @raws[message.id] = raw
        message.reload
      end
    end
  end

  def gallery_raw
    png = file_fixture("pixel.png").binread
    mail = Mail.new do
      from "silvea@example.org"
      to "formations@semisto.org"
      subject "Photos du chantier"
      html_part { content_type "text/html; charset=UTF-8"; body %(<p>Voici <img src="cid:logo@sg"></p>) }
    end
    mail.attachments.inline["logo.png"] = { mime_type: "image/png", content: png }
    mail.attachments.last.content_id = "<logo@sg>"
    mail.attachments["photo.png"] = { mime_type: "image/png", content: png }
    mail.attachments["programme.pdf"] = { mime_type: "application/pdf", content: "%PDF-1.4\n%%EOF\n" }
    mail.attachments["photo.png"] = { mime_type: "image/png", content: "<html><script>alert(1)</script></html>" }
    mail.to_s
  end
end
