class Mailbox < ApplicationRecord
  PROVIDERS = %w[gmail imap].freeze

  acts_as_tenant :account

  serialize :credentials, coder: JSON
  encrypts :credentials

  belongs_to :connected_by, class_name: "User", optional: true
  has_many :mail_folders, dependent: :destroy
  has_many :messages, dependent: :delete_all
  has_many :conversations, dependent: :delete_all
  has_many :accesses, class_name: "MailboxAccess", dependent: :delete_all
  has_many :users_with_access, through: :accesses, source: :user

  scope :accessible_by, ->(user) { where(id: MailboxAccess.where(user: user).select(:mailbox_id)) }
  scope :by_display_name, -> { order(Arel.sql("lower(coalesce(mailboxes.label, mailboxes.address))")) }
  # in:formations dans la recherche : le début du libellé ou de l'adresse.
  scope :starting_with, ->(prefix) {
    pattern = "#{sanitize_sql_like(prefix)}%"
    where("mailboxes.address ILIKE :p OR mailboxes.label ILIKE :p", p: pattern)
  }
  scope :managed_by, ->(user) { where(id: MailboxAccess.where(user: user, level: "manage").select(:mailbox_id)) }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :address, presence: true, uniqueness: { scope: %i[account_id provider] }
  validates :label, length: { maximum: 40 }

  normalizes :label, with: ->(label) { label.squish.presence }

  after_destroy_commit :revoke_google_access

  def access_for(user) = accesses.find_by(user: user)

  def grant!(user, level)
    accesses.find_or_initialize_by(user: user).update!(level: level)
  end

  class LastManagerError < StandardError; end

  # Change l'accès d'une personne depuis une page de partage (level vide = retirer l'accès).
  # La boîte garde toujours au moins une personne qui la gère.
  def change_access!(user, level)
    level = level.presence
    if level != "manage" && access_for(user)&.can_manage? && accesses.where(level: "manage").count == 1
      raise LastManagerError, "Il faut garder au moins une personne qui gère #{address}."
    end

    level ? grant!(user, level) : accesses.where(user: user).delete_all
  end

  def shared? = accesses.size > 1

  # Ce que l'interface affiche : le libellé s'il y en a un, sinon l'adresse.
  def display_name = label || address

  # Pour le champ « De » : « Formations <formations@semisto.org> », ou l'adresse seule.
  def display_name_with_address = label ? "#{label} <#{address}>" : address

  IMAP_SETTINGS = %w[host port username password ssl smtp_host smtp_port].freeze

  # Nouveaux réglages IMAP : un mot de passe laissé vide garde l'actuel.
  def imap_credentials_with(settings)
    settings = settings.to_h.slice(*IMAP_SETTINGS)
    settings.delete("password") if settings["password"].blank?
    settings.reject! { |key, value| value.blank? && credentials.to_h[key].blank? }
    settings["ssl"] = settings["ssl"] != "0" if settings.key?("ssl")
    (credentials || {}).merge(settings)
  end

  def gmail? = provider == "gmail"
  def imap? = provider == "imap"

  def revoke_google_access
    token = credentials&.dig("refresh_token")
    RevokeGoogleTokenJob.perform_later(token) if gmail? && token.present?
  end

  def synchronizer
    gmail? ? GmailSync.new(self) : ImapSync.new(self)
  end

  def sync!
    started_at = Time.current
    synchronizer.call
    # Marge d'un jour : un message importé pendant la synchro précédente n'échappe pas au Screener.
    Conversation.rebuild_for(self, since: last_synced_at&.-(1.day))
    GmailWatch.new(self).renew_if_needed if gmail?
    # La toute première synchro importe l'historique : on ne sonne pas pour des milliers de vieux messages.
    NotifyNewMailJob.perform_later(self, started_at) if last_synced_at
    update!(last_synced_at: Time.current, last_sync_error: nil)
  rescue => e
    update!(last_sync_error: "#{e.class}: #{e.message}")
    raise
  end
end
