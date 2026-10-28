require "test_helper"

class ScreenerTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @shared = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @shared.grant!(users(:michael), "manage")
      @shared.grant!(users(:mohammad), "send")
      # Déjà là avant l'accès : accepté d'office. Puis une réponse de la boîte à Paul.
      inbox_message("old", "t1", "anne@example.org", "Anne", "Inscription", 3.days.ago)
      @shared.messages.create!(provider_uid: "out", thread_key: "t2", sent_at: 2.days.ago, subject: "Devis",
        from_address: "Formations@semisto.org", to_addresses: %w[Paul@example.org], labels: %w[SENT])
      travel 1.hour
      # Nouveaux après l'accès : Zoé n'est connue de personne, Paul a reçu un email de la boîte.
      inbox_message("new1", "t3", "zoe@example.org", "Zoé", "Proposition de partenariat", 1.minute.ago)
      inbox_message("new2", "t4", "zoe@example.org", "Zoé", "Relance", Time.current)
      inbox_message("paul", "t2", "paul@example.org", "Paul", "Re: Devis", Time.current)
      Conversation.rebuild_for(@shared)
      @zoe = Conversation.find_by!(thread_key: "t4")
    end
  end

  test "the thread remembers who opened it, not the mailbox itself" do
    with_account(@semisto) do
      devis = Conversation.find_by!(thread_key: "t2")
      assert_equal [ "paul@example.org", "Paul" ], [ devis.sender_address, devis.sender_name ]
      assert_equal "zoe@example.org", @zoe.sender_address
    end
  end

  test "a new sender waits in the Screener; accepting brings their threads into my inbox only" do
    sign_in_as users(:mohammad)
    with_restricted_database_role do
      get account_root_path(account_id: @semisto.id)
      assert_select "a", "Inscription"
      assert_select "a", "Devis"
      assert_select "a", { text: "Relance", count: 0 }
      assert_select "nav a", "À trier (1)"

      get screenings_path(account_id: @semisto.id)
      assert_select "tr", count: 1
      assert_select "tr strong", "Zoé"
      assert_select "tr a", "Relance"
      assert_select "tr", text: /2 fils/

      post screenings_path(account_id: @semisto.id), params: { address: "Zoe@example.org", decision: "accepted" }
      follow_redirect!
      assert_select "p.notice", /Les emails de zoe@example.org arrivent désormais dans « Réception »/

      get account_root_path(account_id: @semisto.id)
      assert_select "a", "Relance"
      assert_select "a", "Proposition de partenariat"
      assert_select "nav a", "À trier"
    end

    sign_in_as users(:michael)
    get account_root_path(account_id: @semisto.id)
    assert_select "a", { text: "Relance", count: 0 }
    assert_select "nav a", "À trier (1)"
  end

  test "blocking keeps the threads out, search still finds them, unblocking brings them back" do
    sign_in_as users(:michael)
    get conversation_path(@zoe, account_id: @semisto.id)
    assert_select ".screening", /Zoé.*t'écrit pour la première fois/m

    post screenings_path(account_id: @semisto.id), params: { address: "zoe@example.org", decision: "blocked" }
    get screenings_path(account_id: @semisto.id)
    assert_select "table.screener tr", count: 0
    assert_select "h2", "Bloqués"

    get search_path(account_id: @semisto.id, q: "relance")
    assert_select "a", "Relance"
    get conversation_path(@zoe, account_id: @semisto.id)
    assert_select ".screening", /Tu as bloqué/

    post screenings_path(account_id: @semisto.id), params: { address: "zoe@example.org", decision: "accepted" }
    get account_root_path(account_id: @semisto.id)
    assert_select "a", "Relance"
  end

  test "accepted into the Feed or the Paper Trail, then moved, for me only" do
    sign_in_as users(:mohammad)
    get screenings_path(account_id: @semisto.id)
    assert_equal [ "Réception", "Feed", "Paper Trail", "Bloquer" ], css_select("tr button").map(&:text)

    post screenings_path(account_id: @semisto.id), params: { address: "zoe@example.org", decision: "accepted", bucket: "feed" }
    follow_redirect!
    assert_select "p.notice", /arrivent désormais dans « Feed »/
    get account_root_path(account_id: @semisto.id)
    assert_select "a", { text: "Relance", count: 0 }
    get conversations_path(account_id: @semisto.id, box: "feed")
    assert_select "h1", "Feed"
    assert_select "a", "Relance"
    assert_select "a", { text: "Inscription", count: 0 }

    # Déplacer Anne (acceptée d'office dans la réception) vers le Paper Trail depuis un de ses fils.
    post screenings_path(account_id: @semisto.id), params: { address: "anne@example.org", decision: "accepted", bucket: "paper_trail" }
    get conversations_path(account_id: @semisto.id, box: "paper_trail")
    assert_select "a", "Inscription"
    get account_root_path(account_id: @semisto.id)
    assert_select "a", { text: "Inscription", count: 0 }
    assert_select "a", "Devis"

    # « Tout marquer comme lu » dans le Feed ne touche pas la réception.
    post mark_all_read_conversations_path(account_id: @semisto.id, box: "feed")
    get conversations_path(account_id: @semisto.id, box: "feed")
    assert_select "tr.unread", count: 0
    get account_root_path(account_id: @semisto.id)
    assert_select "tr.unread a", "Devis"

    sign_in_as users(:michael)
    get account_root_path(account_id: @semisto.id)
    assert_select "a", "Inscription"
  end

  test "an accepted sender can be blocked from the thread" do
    sign_in_as users(:michael)
    inscription = with_account(@semisto) { Conversation.find_by!(thread_key: "t1") }
    get conversation_path(inscription, account_id: @semisto.id)
    assert_select ".actions", /rangés dans « Réception »/
    assert_equal [ "Marquer comme non lu", "Feed", "Paper Trail", "Bloquer" ], css_select(".actions button").map(&:text)
  end

  test "someone who gets access later finds the history already accepted" do
    with_account(@semisto) do
      travel 1.hour
      @semisto.memberships.create!(user: users(:lea), role: "member") unless @semisto.memberships.exists?(user: users(:lea))
      @shared.grant!(users(:lea), "read")
      assert_equal %w[anne@example.org paul@example.org zoe@example.org],
        Screening.where(user: users(:lea)).order(:address).pluck(:address)
    end
  end

  test "an unknown decision is refused" do
    sign_in_as users(:michael)
    post screenings_path(account_id: @semisto.id), params: { address: "zoe@example.org", decision: "maybe" }
    follow_redirect!
    assert_select "p.alert", "Décision inconnue."
  end

  private

  def inbox_message(uid, thread, address, name, subject, sent_at)
    @shared.messages.create!(provider_uid: uid, thread_key: thread, from_address: address, from_name: name,
      subject: subject, sent_at: sent_at, labels: %w[INBOX])
  end
end
