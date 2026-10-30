# L'agent d'une personne (note sg-mail-agent) : son prénom, sa couleur et son style, comme dans Notion.
# Le même dans tous les clients de la personne ; il n'existe en base qu'une fois ses réglages enregistrés.
class Agent < ApplicationRecord
  # Les couleurs des espaces de SG Mail (variables CSS du même nom).
  COLORS = { "imbox" => "Mauve", "feed" => "Sauge", "trail" => "Kraft", "screener" => "Prune", "later" => "Corail", "aside" => "Ardoise" }.freeze
  STYLES = {
    "concise" => { label: "Concis", hint: "Va droit au but, en quelques lignes.",
                   prompt: "Be brief and to the point: a few short sentences or a short list, no preamble." },
    "warm" => { label: "Chaleureux", hint: "Amical et encourageant, tutoie.",
                prompt: "Be warm and friendly, address the person informally (tutoiement in French), stay concise." },
    "formal" => { label: "Formel", hint: "Posé et soigné, vouvoie.",
                  prompt: "Be courteous and polished, address the person formally (vouvoiement in French)." }
  }.freeze
  DEFAULTS = { name: "Plume", color: "imbox", style: "concise" }.freeze
  INSTRUCTIONS_LIMIT = 500
  AVATAR_TYPES = AttachmentServing::VIEWABLE_IMAGES
  AVATAR_MAX_SIZE = 2.megabytes

  belongs_to :user
  has_one_attached :avatar

  normalizes :name, with: ->(name) { name.squish }
  normalizes :instructions, with: ->(text) { text.strip.presence }

  validates :name, presence: true, length: { maximum: 30 }
  validates :color, inclusion: { in: COLORS.keys }
  validates :style, inclusion: { in: STYLES.keys }
  validates :instructions, length: { maximum: INSTRUCTIONS_LIMIT }
  validate :avatar_is_a_small_image, if: -> { avatar.attached? && attachment_changes["avatar"] }

  def self.for(user) = find_by(user: user) || new(user: user, **DEFAULTS)

  def initial = name.first.upcase
  def style_prompt = STYLES.fetch(style)[:prompt]

  private

  # Une photo ou un dessin (PNG, JPEG, GIF, WebP) : jamais de SVG, qui pourrait exécuter du code.
  def avatar_is_a_small_image
    errors.add(:avatar, "doit être une image PNG, JPEG, GIF ou WebP") unless avatar.blob.content_type.in?(AVATAR_TYPES)
    errors.add(:avatar, "ne doit pas dépasser 2 Mo") if avatar.blob.byte_size > AVATAR_MAX_SIZE
  end
end
