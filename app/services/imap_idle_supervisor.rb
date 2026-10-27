# Un fil par boîte IMAP, tous clients confondus, qui écoute en IDLE et lance SyncMailboxJob.
# Tourne dans son propre processus : bin/rails sg_mail:idle (lancé par bin/dev).
class ImapIdleSupervisor
  REFRESH_INTERVAL = 60
  MAX_BACKOFF = 15 * 60

  def initialize(logger: Rails.logger, idle_class: ImapIdle)
    @logger = logger
    @idle_class = idle_class
    @listeners = {}
    @stopping = false
  end

  def run
    %w[INT TERM].each { |signal| trap(signal) { @stopping = true } }
    until @stopping
      refresh
      REFRESH_INTERVAL.times { break if @stopping; sleep 1 }
    end
  ensure
    @listeners.each_value { |listener| listener[:thread].kill }
  end

  # Démarre un fil pour chaque nouvelle boîte, arrête ceux des boîtes déconnectées
  # ou dont les identifiants ont changé.
  def refresh
    mailboxes = Rails.application.executor.wrap do
      Tenancy.across_accounts { Mailbox.where(provider: "imap").to_a }
    end
    wanted = mailboxes.to_h { |mailbox| [ mailbox.id, mailbox ] }

    @listeners.each do |id, listener|
      next if wanted[id]&.updated_at == listener[:updated_at] && listener[:thread].alive?

      listener[:stop] = true
      @listeners.delete(id)
    end
    wanted.each_value { |mailbox| @listeners[mailbox.id] ||= listen(mailbox) }
  end

  def listening_to = @listeners.keys

  private

  def listen(mailbox)
    listener = { updated_at: mailbox.updated_at, stop: false }
    listener[:thread] = Thread.new do
      attempt = 0
      until listener[:stop] || @stopping
        begin
          @idle_class.new(mailbox.credentials, on_change: -> { enqueue_sync(mailbox) })
            .run(stop: -> { listener[:stop] || @stopping })
        rescue => e
          attempt += 1
          @logger.warn("IMAP IDLE #{mailbox.address} : #{e.class}: #{e.message}")
          sleep [ 2**attempt, MAX_BACKOFF ].min
        end
      end
    end
    listener
  end

  def enqueue_sync(mailbox)
    Rails.application.executor.wrap do
      account = Tenancy.across_accounts { mailbox.account }
      Tenancy.with_account(account) { SyncMailboxJob.perform_later(mailbox) }
    end
  end
end
