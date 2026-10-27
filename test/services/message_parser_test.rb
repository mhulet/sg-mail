require "test_helper"

class MessageParserTest < ActiveSupport::TestCase
  test "parse un message multipart en latin-1 avec pièce jointe" do
    attrs = MessageParser.parse(file_fixture("latin1_html_with_attachment.eml").binread)

    assert_equal "Inscription à la formation", attrs[:subject]
    assert_equal "silvea@example.org", attrs[:from_address]
    assert_equal "Sylvéa", attrs[:from_name]
    assert_equal [ "formations@semisto.org" ], attrs[:to_addresses]
    assert_equal [ "michael@example.org" ], attrs[:cc_addresses]
    assert_equal "reply-1@example.org", attrs[:message_id_header]
    assert_equal "root-1@example.org", attrs[:thread_key]
    assert_includes attrs[:body_text], "formation d'été"
    assert_includes attrs[:body_html], "<p>Bonjour"
    assert attrs[:has_attachments]
    assert_equal Time.utc(2026, 10, 26, 8, 15), attrs[:sent_at]
    assert attrs[:body_text].valid_encoding?
  end

  test "un message texte simple sans en-têtes MIME" do
    attrs = MessageParser.parse("From: a@example.org\r\nSubject: Salut\r\nMessage-ID: <x@example.org>\r\n\r\nCorps\u0000 du message\r\n")

    assert_equal "Corps du message", attrs[:body_text].strip
    assert_nil attrs[:body_html]
    assert_equal "x@example.org", attrs[:thread_key]
  end
end
