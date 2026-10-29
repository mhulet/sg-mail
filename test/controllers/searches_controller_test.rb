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
    assert_select "td.subject a mark", text: "Inscription"
    get search_path(account_id: semisto.id, q: "bonjour")
    assert_select "td.subject .snippet mark", text: "Bonjour"
    get search_path(account_id: semisto.id, q: "rien")
    assert_select "p", text: "Aucun résultat."
    get search_path(account_id: semisto.id, q: "from:anne is:starred")
    assert_select "turbo-frame#search_results table.conversations tr", 1
    assert_select "code", text: "is:starred"
  end

  test "while typing, the menu field gets a short preview" do
    semisto = accounts(:semisto)
    with_account(semisto) do
      mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      mailbox.grant!(users(:mohammad), "read")
      10.times do |i|
        mailbox.messages.create!(provider_uid: i.to_s, thread_key: "t#{i}", subject: "Inscription #{i}", from_address: "anne@example.org",
          sent_at: i.hours.ago, labels: %w[INBOX])
      end
      Conversation.rebuild_for(mailbox)
    end

    sign_in_as users(:mohammad)
    get search_path(account_id: semisto.id, q: "inscri"), headers: { "Turbo-Frame" => "search_preview" }
    assert_select "turbo-frame#search_preview a.result", SearchesController::PREVIEW_LIMIT
    assert_select "turbo-frame#search_preview a.all[href*='q=inscri']"
    assert_select "aside, nav", 0
  end
end
