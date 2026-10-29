class Message < ApplicationRecord
  # Colonne calculée par Postgres pour la recherche (voir MessageSearch) : inutile à charger.
  self.ignored_columns += %w[search_vector]

  acts_as_tenant :account
  belongs_to :mailbox
  belongs_to :mail_folder, optional: true
  belongs_to :conversation, optional: true
  has_many :readings, dependent: :delete_all
  # Les pièces jointes déjà rapatriées du fournisseur (voir AttachmentCache).
  has_many_attached :attachment_files

  before_validation { self.account_id ||= mailbox&.account_id }

  scope :recent, -> { order(sent_at: :desc) }

  def from_display = from_name.presence || from_address

  # Les images intégrées au corps (<img src="cid:…">) s'affichent dans le message, pas dans la liste.
  def listed_attachments
    attachments.reject { |attachment| attachment["content_id"].in?(inline_content_ids) }
  end

  def inline_content_ids
    @inline_content_ids ||= body_html.to_s.scan(/cid:([^"'\s)>]+)/i).flatten.map { |cid| CGI.unescape(cid) }.to_set
  end

  def read_by?(user) = readings.any? { |reading| reading.user_id == user.id }

  def unread_in_provider?
    labels.include?("UNREAD") || (mailbox.imap? && !labels.include?("Seen"))
  end
end
