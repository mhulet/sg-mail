require "test_helper"

class MessageSearchTest < ActiveSupport::TestCase
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @formations = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @formations.grant!(users(:mohammad), "read")
      @perso = Mailbox.create!(provider: "imap", address: "michael@example.org")
      @perso.grant!(users(:michael), "manage")
      @ete = @formations.messages.create!(provider_uid: "1", thread_key: "t1", subject: "Inscription formation d'été",
        from_address: "anne@example.org", from_name: "Anne", to_addresses: %w[formations@semisto.org], sent_at: 2.days.ago,
        body_text: "Bonjour, je voudrais m'inscrire.", labels: %w[INBOX])
      @facture = @formations.messages.create!(provider_uid: "2", thread_key: "t2", subject: "Facture",
        from_address: "compta@example.org", sent_at: 1.day.ago, body_html: "<p>Votre <b>facture</b> d'octobre</p>",
        has_attachments: true, labels: %w[INBOX])
      @secret = @perso.messages.create!(provider_uid: "INBOX/1/1", thread_key: "t3", subject: "Formation perso",
        from_address: "ami@example.org", sent_at: 1.day.ago, body_text: "Rien à voir", labels: [])
      Conversation.rebuild_for(@formations)
      Conversation.rebuild_for(@perso)
    end
  end

  test "finds words without accents and by prefix, across subject and body" do
    assert_equal [ @ete ], search(users(:mohammad), "ete inscri")
    assert_equal [ @ete ], search(users(:mohammad), "VOUDRAIS")
    assert_equal [ @facture ], search(users(:mohammad), "octobre"), "le HTML seul est indexé"
  end

  test "filters on sender, recipient and attachments" do
    assert_equal [ @ete ], search(users(:mohammad), "de:anne")
    assert_equal [ @ete ], search(users(:mohammad), "a:formations@")
    assert_equal [ @facture ], search(users(:mohammad), "avec:pj")
  end

  test "only searches mailboxes the person can read" do
    assert_equal [ @ete ], search(users(:mohammad), "formation")
    assert_equal [ @secret ], search(users(:michael), "formation perso")
  end

  test "tsquery syntax in the input is harmless" do
    assert_empty search(users(:mohammad), "') | (:* !")
    assert MessageSearch.new(users(:mohammad), "  ").blank?
  end

  private

  def search(user, query)
    with_account(@semisto) { MessageSearch.new(user, query).messages.order(:id).to_a }
  end
end
