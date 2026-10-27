require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  test "search results are threads, shown with the usual list" do
    semisto = accounts(:semisto)
    with_account(semisto) do
      mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      mailbox.grant!(users(:mohammad), "read")
      mailbox.messages.create!(provider_uid: "1", thread_key: "t1", subject: "Inscription", from_address: "anne@example.org",
        sent_at: 1.day.ago, body_text: "Bonjour", labels: %w[INBOX])
      Conversation.rebuild_for(mailbox)
    end

    sign_in_as users(:mohammad)
    get search_path(account_id: semisto.id, q: "inscription")
    assert_select "table.conversations tr", 1
    get search_path(account_id: semisto.id, q: "rien")
    assert_select "p", text: "Aucun résultat."
  end
end
