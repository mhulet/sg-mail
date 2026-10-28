module ApplicationHelper
  # Couleurs des avatars et des pastilles de boîte : toujours la même pour un même nom.
  TINTS = %w[#7b4fc9 #b0603a #2f7d6d #5b5781 #a06a26 #3d6a8c #8c4a6b #4c7a57].freeze

  # Chaque espace a sa couleur (voir application.css) ; la page la reprend pour ses accents.
  SPACES = { "imbox" => "imbox", "feed" => "feed", "paper_trail" => "trail", "reply_later" => "later", "set_aside" => "aside" }.freeze

  # « À trier (3) » : le nombre d'expéditeurs qui attendent une décision dans le Screener.
  def screener_label
    count = Conversation.accessible_by(Current.user).screening_pending_for(Current.user).distinct.count(:sender_address)
    count.zero? ? "À trier" : "À trier (#{count})"
  end

  # Lien de navigation, marqué comme page courante quand on y est. Avec space:, une pastille de sa couleur.
  def nav_link(label, path, shortcut: nil, space: nil)
    content = space ? safe_join([ tag.span(class: "dot", aria: { hidden: true }), label ]) : label
    link_to content, path, aria: { current: ("page" if current_page?(path)) }, data: { shortcut: shortcut },
      style: ("--c: var(--#{space})" if space)
  end

  # L'espace de la page affichée, pour sa couleur : la pile ou la boîte de la liste, le Screener, sinon la réception.
  def current_space
    return "screener" if controller_name == "screenings"
    return "imbox" unless controller_name == "conversations"

    key = @stack || (action_name == "show" ? @bucket : @box)
    SPACES.fetch(key.to_s, "imbox")
  end

  # Sous le titre d'un espace : à quoi il sert.
  SPACE_TAGLINES = {
    "imbox" => "Les gens qui comptent, et rien d'autre.",
    "feed" => "Lettres d'info et lectures, à parcourir quand tu as le temps.",
    "paper_trail" => "Reçus, confirmations et notifications : gardés ici, sans encombrer ta réception.",
    "reply_later" => "Les fils que tu as gardés pour y répondre. Ils quittent cette pile quand tu y réponds.",
    "set_aside" => "Les fils que tu gardes sous la main pour t'y référer.",
    "archived" => "Les fils que tu as archivés. Chacun revient dans ta réception au prochain message."
  }.freeze

  # Quand un espace est vide : une petite récompense plutôt qu'un « Rien ici ».
  SPACE_EMPTY_LINES = {
    "imbox" => "Ta réception est vide. Belle journée.",
    "feed" => "Plus rien à lire. Va voir dehors.",
    "paper_trail" => "Aucun reçu, aucune notification.",
    "reply_later" => "Aucune promesse en attente.",
    "set_aside" => "Rien de côté pour l'instant.",
    "archived" => "Rien d'archivé pour l'instant."
  }.freeze

  def space_tagline(key) = SPACE_TAGLINES.fetch(key.to_s, SPACE_TAGLINES["imbox"])
  def space_empty_line(key) = SPACE_EMPTY_LINES.fetch(key.to_s, "Rien ici.")

  def tint_for(text)
    TINTS[text.to_s.downcase.sum % TINTS.size]
  end

  # Un rond aux initiales, à la couleur du nom.
  def avatar(name, size: nil)
    initials = name.to_s.scan(/[[:alpha:]]+/).first(2).map { |word| word[0] }.join.upcase
    tag.span(initials.presence || "?", class: [ "avatar", size ], style: "--av: #{tint_for(name)}", aria: { hidden: true })
  end

  # La boîte d'un fil, avec une pastille de sa couleur.
  def mailbox_chip(address)
    tag.span(address, class: "mailbox-chip", style: "--mb: #{tint_for(address)}")
  end
end
