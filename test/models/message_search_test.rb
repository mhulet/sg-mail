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
        cc_addresses: %w[marc@example.org], has_attachments: true, labels: %w[INBOX],
        attachments: [ { "index" => 0, "filename" => "Devis_jardin-forêt.pdf", "content_type" => "application/pdf", "size" => 10 } ])
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

  test "the former French filters still work" do
    assert_equal [ @ete ], search(users(:mohammad), "de:anne")
    assert_equal [ @ete ], search(users(:mohammad), "a:formations@")
    assert_equal [ @facture ], search(users(:mohammad), "avec:pj")
  end

  test "Gmail operators on messages" do
    mohammad = users(:mohammad)
    assert_equal [ @ete ], search(mohammad, "from:anne")
    assert_equal [ @ete ], search(mohammad, "from:Anne inscri")
    assert_equal [ @ete ], search(mohammad, "to:formations@")
    assert_equal [ @facture ], search(mohammad, "cc:marc")
    assert_equal [ @facture ], search(mohammad, "subject:factu")
    assert_equal [ @ete ], search(mohammad, %(subject:"formation d'ete"))
    assert_equal [ @facture ], search(mohammad, "has:attachment")
    assert_equal [ @facture ], search(mohammad, "filename:pdf")
    assert_equal [ @ete ], search(mohammad, "-has:attachment")
    assert_equal [ @facture ], search(mohammad, "-from:anne")
    assert_equal [ @facture ], search(mohammad, "-inscription")
  end

  test "words also match attachment names, and quotes match an exact phrase" do
    assert_equal [ @facture ], search(users(:mohammad), "foret devis")
    assert_equal [ @ete ], search(users(:mohammad), %("je voudrais"))
    assert_empty search(users(:mohammad), %("voudrais je"))
  end

  test "dates" do
    mohammad = users(:mohammad)
    assert_equal [ @facture ], search(mohammad, "after:#{1.day.ago.to_date.iso8601.tr('-', '/')}")
    assert_equal [ @ete ], search(mohammad, "before:#{1.day.ago.to_date.iso8601}")
    assert_equal [ @ete, @facture ], search(mohammad, "after:#{3.days.ago.to_date.strftime('%d/%m/%Y')}")
    assert_equal [ @ete ], search(mohammad, "older_than:2d")
    assert_equal [ @facture ], search(mohammad, "newer_than:2d")
    assert_equal [ @ete, @facture ], search(mohammad, "newer_than:1w")
  end

  test "unknown operator values are reported and ignored" do
    search = MessageSearch.new(users(:mohammad), "is:starred after:hier formation")
    assert_equal [ "is:starred", "after:hier" ], search.errors
    assert_equal [ @ete ], with_account(@semisto) { search.messages.to_a }
  end

  test "words find threads by their internal notes" do
    with_account(@semisto) do
      Note.create!(conversation: @facture.reload.conversation, user: users(:mohammad), body: "Payée par virement")
      Note.create!(conversation: @ete.reload.conversation, user: users(:mohammad), body: "Rappeler Anne pour l'acompte")
    end
    assert_equal [ @facture.conversation ], conversations(users(:mohammad), "virement")
    assert_equal [ @ete.conversation ], conversations(users(:mohammad), "acompte rappeler")
    assert_equal [ @ete.conversation ], conversations(users(:mohammad), "acompte from:anne")
    assert_empty conversations(users(:mohammad), "acompte from:compta")
    assert_equal [ @ete.conversation, @facture.conversation ].sort_by(&:id), conversations(users(:mohammad), "has:note")
    assert_empty conversations(users(:michael), "virement"), "une note ne sort pas des boîtes accessibles"
  end

  test "operators on threads: read state, assignee, piles and mailboxes" do
    mohammad = users(:mohammad)
    with_account(@semisto) do
      Reading.mark!(mohammad, Message.where(id: @ete))
      @facture.reload.conversation.update!(assignee: mohammad)
      ConversationState.archive!(@ete.reload.conversation, mohammad)
    end
    assert_equal [ @facture.conversation ], conversations(mohammad, "is:unread")
    assert_equal [ @ete.conversation ], conversations(mohammad, "is:read")
    assert_equal [ @facture.conversation ], conversations(mohammad, "is:assigned")
    assert_equal [ @facture.conversation ], conversations(mohammad, "assignee:me")
    assert_equal [ @facture.conversation ], conversations(mohammad, "assignee:moham")
    assert_equal [ @ete.conversation ], conversations(mohammad, "is:unassigned")
    assert_equal [ @ete.conversation ], conversations(mohammad, "in:archive")
    assert_equal [ @facture.conversation ], conversations(mohammad, "-in:archive")
    assert_equal [ @ete.conversation, @facture.conversation ], conversations(mohammad, "in:formations")
    secret = with_account(@semisto) { @secret.reload.conversation }
    assert_equal [ secret ], conversations(users(:michael), "in:michael formation")
    assert_equal [ "in:michael" ], with_account(@semisto) { MessageSearch.new(mohammad, "in:michael").errors }, "boîte non accessible"
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

  def conversations(user, query)
    with_account(@semisto) { MessageSearch.new(user, query).conversations.order(:id).to_a }
  end
end
