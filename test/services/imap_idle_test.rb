require "test_helper"

class ImapIdleTest < ActiveSupport::TestCase
  # Serveur IMAP simulé : chaque appel à idle rejoue la réponse suivante de la liste.
  class FakeImap
    attr_reader :examined, :idle_done_calls

    def initialize(responses) = (@responses = responses; @idle_done_calls = 0)
    def examine(name) = @examined = name
    def idle(_timeout) = (response = @responses.shift) && yield(response)
    def idle_done = @idle_done_calls += 1
    def logout = nil
    def disconnect = nil
  end

  def untagged(name) = Net::IMAP::UntaggedResponse.new(name, 1, "")

  test "signals a change on EXISTS and EXPUNGE, not on other responses" do
    imap = FakeImap.new([ untagged("EXISTS"), untagged("FETCH"), untagged("EXPUNGE"), nil ])
    rounds = 0
    changes = 0

    ImapIdle.new({}, on_change: -> { changes += 1 }, connector: ->(_credentials) { imap })
      .run(stop: -> { (rounds += 1) > 4 })

    assert_equal "INBOX", imap.examined
    assert_equal 3, changes # rattrapage au démarrage + EXISTS + EXPUNGE
    assert_equal 2, imap.idle_done_calls
  end
end
