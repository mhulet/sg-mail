# Recherche dans les messages des boîtes accessibles, rendue par fil.
#
# Les mots sont cherchés partout (objet, expéditeur, destinataires, corps), sans accents et
# en début de mot : « inscri » trouve « Inscription ». Filtres possibles dans la requête :
#   de:anne       expéditeur (adresse ou nom)
#   a:formations  destinataire ou copie
#   avec:pj       messages avec pièces jointes
class MessageSearch
  FILTERS = { "de" => :from, "from" => :from, "a" => :to, "à" => :to, "to" => :to, "avec" => :with }.freeze

  attr_reader :query, :words, :filters

  def initialize(user, query, mailbox: nil)
    @user = user
    @mailbox = mailbox
    @query = query.to_s.strip
    parse
  end

  def blank? = words.empty? && filters.empty?

  def messages
    return Message.none if blank?

    mailboxes = Mailbox.accessible_by(@user)
    mailboxes = mailboxes.where(id: @mailbox) if @mailbox
    scope = Message.where(mailbox: mailboxes)
    if words.any?
      tsquery = words.map { |word| "#{word}:*" }.join(" & ")
      scope = scope.where("messages.search_vector @@ to_tsquery('simple', public.sg_mail_unaccent(?))", tsquery)
    end
    filters.fetch(:from, []).each do |value|
      scope = scope.where("messages.from_address ILIKE :v OR messages.from_name ILIKE :v", v: like(value))
    end
    filters.fetch(:to, []).each do |value|
      scope = scope.where("(messages.to_addresses::text || messages.cc_addresses::text) ILIKE ?", like(value))
    end
    scope = scope.where(has_attachments: true) if filters.fetch(:with, []).include?("pj")
    scope
  end

  def conversations
    Conversation.where(id: messages.where.not(conversation_id: nil).select(:conversation_id))
  end

  private

  def parse
    @words = []
    @filters = {}
    query.split(/\s+/).each do |token|
      key, value = token.split(":", 2)
      if value.present? && (filter = FILTERS[key.downcase])
        (@filters[filter] ||= []) << value.downcase
      else
        # Seuls les lettres et les chiffres passent : rien ne peut casser la syntaxe de to_tsquery.
        @words.concat(token.downcase.scan(/[\p{L}\p{N}]+/))
      end
    end
  end

  def like(value) = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
end
