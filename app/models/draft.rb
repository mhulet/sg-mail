# Un message en cours de rédaction : nouveau, réponse, réponse à tous ou transfert.
# Seule son autrice le voit ; l'envoi passe par SendDraftJob (MailSender).
class Draft < ApplicationRecord
  KINDS = %w[new reply reply_all forward].freeze
  STATUSES = %w[draft sending sent failed].freeze

  acts_as_tenant :account
  belongs_to :mailbox
  belongs_to :user
  belongs_to :conversation, optional: true
  belongs_to :source_message, class_name: "Message", optional: true

  before_validation { self.account_id ||= mailbox&.account_id }

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validate :addresses_are_valid
  validate :sender_can_send, if: -> { mailbox && user }

  scope :editable, -> { where(status: %w[draft failed]) }

  # Un nouveau message, avec la signature de la personne pour cette boîte.
  def self.start(user:, mailbox:, body: nil)
    new(kind: "new", user: user, mailbox: mailbox, body: "#{body}#{signature_block(user, mailbox)}".presence)
  end

  # « -- » puis la signature, séparée du texte par une ligne vide ; rien sans signature.
  def self.signature_block(user, mailbox)
    signature = mailbox&.access_for(user)&.signature
    signature.present? ? "\n\n-- \n#{signature.strip}" : ""
  end

  # Prépare un brouillon à partir d'un message reçu, avec la citation et les bons destinataires.
  # La signature se place entre la réponse et la citation.
  def self.build_from(message, kind:, user:, mailbox: nil)
    mailbox ||= message.mailbox
    own_addresses = [ mailbox.address, message.mailbox.address ].map(&:downcase)
    draft = new(kind: kind, user: user, mailbox: mailbox, conversation: message.conversation, source_message: message)

    case kind
    when "reply", "reply_all"
      sender = message.from_address.to_s
      sender = message.to_addresses.first.to_s if own_addresses.include?(sender.downcase) # répondre à son propre envoi
      draft.to_addresses = [ sender ]
      if kind == "reply_all"
        others = (message.to_addresses + message.cc_addresses).reject { |a| own_addresses.include?(a.downcase) || a.casecmp?(sender) }
        draft.cc_addresses = others.uniq(&:downcase)
      end
      draft.subject = prefixed(message.subject, "Re")
      draft.body = "#{signature_block(user, mailbox)}\n\n#{quote(message)}"
    when "forward"
      draft.subject = prefixed(message.subject, "Fwd")
      draft.body = "#{signature_block(user, mailbox)}\n\n---------- Message transféré ----------\n" \
        "De : #{message.from_display} <#{message.from_address}>\n" \
        "Date : #{message.sent_at && I18n.l(message.sent_at, format: :long)}\n" \
        "Objet : #{message.subject}\n" \
        "À : #{message.to_addresses.join(", ")}\n\n#{message.body_text}"
    end
    draft
  end

  def self.prefixed(subject, prefix)
    subject = subject.to_s
    subject.match?(/\A#{prefix}\s*:/i) ? subject : "#{prefix}: #{subject}".strip
  end

  def self.quote(message)
    intro = "Le #{message.sent_at && I18n.l(message.sent_at, format: :long)}, #{message.from_display} a écrit :"
    quoted = message.body_text.to_s.strip.lines.map { |line| "> #{line}" }.join
    "#{intro}\n#{quoted}"
  end

  def editable? = status.in?(%w[draft failed])
  def reply? = kind.in?(%w[reply reply_all])
  def forward? = kind == "forward"

  def recipients = to_addresses + cc_addresses + bcc_addresses

  # Champs de formulaire « a@x, b@y » ↔ listes.
  %i[to cc bcc].each do |field|
    define_method(:"#{field}_list") { public_send(:"#{field}_addresses").join(", ") }
    define_method(:"#{field}_list=") do |value|
      public_send(:"#{field}_addresses=", value.to_s.split(/[,;\n]/).map(&:strip).reject(&:blank?))
    end
  end

  private

  def addresses_are_valid
    invalid = recipients.reject { |address| address.match?(URI::MailTo::EMAIL_REGEXP) || address.match?(/<[^>]+@[^>]+>\z/) }
    errors.add(:base, "Adresse invalide : #{invalid.join(", ")}") if invalid.any?
  end

  def sender_can_send
    errors.add(:mailbox, "ne t'autorise pas à envoyer") unless mailbox.access_for(user)&.can_send?
  end
end
