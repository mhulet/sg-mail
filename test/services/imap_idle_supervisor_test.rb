require "test_helper"

class ImapIdleSupervisorTest < ActiveSupport::TestCase
  # Écoute factice : tourne jusqu'à ce qu'on lui demande d'arrêter.
  class FakeIdle
    def initialize(_credentials, on_change:) = nil
    def run(stop:) = (sleep 0.01 until stop.call)
  end

  test "listens to every IMAP mailbox across accounts, and stops for disconnected ones" do
    imap = with_account(accounts(:semisto)) { Mailbox.create!(provider: "imap", address: "a@semisto.org") }
    other = with_account(accounts(:silvea)) { Mailbox.create!(provider: "imap", address: "b@silvea.be") }
    with_account(accounts(:semisto)) { Mailbox.create!(provider: "gmail", address: "c@semisto.org") }

    supervisor = ImapIdleSupervisor.new(idle_class: FakeIdle)
    supervisor.refresh
    assert_equal [ imap.id, other.id ].sort, supervisor.listening_to.sort

    with_account(accounts(:silvea)) { other.destroy! }
    supervisor.refresh
    assert_equal [ imap.id ], supervisor.listening_to
  end
end
