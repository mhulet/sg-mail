# Recherche dans les boîtes accessibles, rendue par fil, avec les opérateurs de Gmail (en anglais).
#
# Les mots sont cherchés partout (objet, expéditeur, destinataires, corps, noms des pièces jointes), sans
# accents et en début de mot : « inscri » trouve « Inscription ». Ils trouvent aussi les fils par leurs
# notes internes et leurs tâches. "bon de commande" cherche l'expression exacte ; -mot exclut.
#
# Opérateurs (une valeur avec espaces se met entre guillemets, -from:anne exclut) :
#   from:anne  to:formations  cc:marc  subject:devis  filename:pdf  has:attachment  has:note  has:task
#   before:2026/10/01  after:2026-09-15  older_than:2w  newer_than:3d   (jours d, semaines w, mois m, années y)
#   in:inbox in:feed in:paper_trail in:screener in:reply_later in:set_aside in:archive in:sent in:formations
#   is:unread  is:read  is:assigned  is:unassigned  assignee:me  assignee:anne  mailbox:formations
class MessageSearch
  OPERATORS = %w[from to cc subject filename has before after older_than newer_than in is assignee mailbox].freeze
  # Les anciens filtres en français restent compris.
  ALIASES = { "de" => "from", "a" => "to", "à" => "to", "avec" => "has", "label" => "in" }.freeze
  TERM = /(-)?(?:([\p{L}_]+):)?("[^"]*"?|\S+)/
  PERIODS = { "d" => :days, "w" => :weeks, "m" => :months, "y" => :years }.freeze
  IN_ALIASES = { "inbox" => "imbox", "later" => "reply_later", "aside" => "set_aside", "paper-trail" => "paper_trail",
    "papertrail" => "paper_trail", "archived" => "archive", "all" => "anywhere" }.freeze

  Term = Data.define(:negated, :operator, :value)

  attr_reader :query, :words, :terms, :errors

  def initialize(user, query, mailbox: nil)
    @user = user
    @mailbox = mailbox
    @query = query.to_s.strip
    parse
  end

  def blank? = words.empty? && terms.empty?

  # Les messages qui répondent à tous les critères portant sur un message (mots compris).
  def messages
    return Message.none if blank?

    scope = message_scope
    scope = scope.where("messages.search_vector @@ to_tsquery('simple', public.sg_mail_unaccent(?))", tsquery) if words.any?
    scope
  end

  # Les fils : un de leurs messages répond, ou leurs notes et tâches contiennent les mots, puis les
  # critères propres au fil (in:, is:, assignee:, has:note…).
  def conversations
    return Conversation.none if blank?

    ids = messages.where.not(conversation_id: nil).select(:conversation_id)
    scope = Conversation.where(id: ids)
    if words.any? { |word| !word.negated }
      scope = scope.or(Conversation.where(id: message_scope.select(:conversation_id)).where(id: annotated_ids))
    end
    terms.select { |term| conversation_term?(term) }.each do |term|
      condition = conversation_condition(term)
      scope = term.negated ? scope.where.not(id: condition.select(:id)) : scope.where(id: condition.select(:id))
    end
    scope
  end

  # Les mots à surligner dans les résultats (ceux qu'on cherche, pas ceux qu'on exclut).
  def highlights = words.reject(&:negated).flat_map(&:value).uniq

  # Pour chaque fil, le message le plus récent qui répond à la recherche : { conversation_id => message }.
  def matching_messages(conversation_ids)
    return {} if blank? || conversation_ids.empty?

    messages.where(conversation_id: conversation_ids)
      .select("DISTINCT ON (messages.conversation_id) messages.*")
      .reorder("messages.conversation_id", sent_at: :desc, id: :desc).index_by(&:conversation_id)
  end

  private

  def parse
    @words = []
    @terms = []
    @errors = []
    query.scan(TERM) do |negated, operator, value|
      negated = negated.present?
      phrase = value.start_with?('"')
      value = value.delete('"')
      operator = ALIASES.fetch(operator.to_s.downcase, operator.to_s.downcase)
      if operator.in?(OPERATORS) && value.present?
        term = Term.new(negated, operator, value.downcase)
        valid?(term) ? @terms << term : @errors << "#{operator}:#{value}"
      else
        # Un mot inconnu suivi de « : » (https://…) reste du texte. Seuls les lettres et les chiffres
        # passent : rien ne peut casser la syntaxe de to_tsquery.
        text = [ operator.presence, value ].compact.join(" ")
        tokens = text.downcase.scan(/[\p{L}\p{N}]+/)
        if phrase && tokens.many?
          @words << Term.new(negated, :phrase, tokens)
        else
          tokens.each { |token| @words << Term.new(negated, :word, [ token ]) }
        end
      end
    end
  end

  def valid?(term)
    case term.operator
    when "has" then term.value.in?(%w[attachment attachments pj note notes task tasks])
    when "before", "after" then date(term.value).present?
    when "older_than", "newer_than" then term.value.match?(/\A\d+[dwmy]\z/)
    when "in" then in_value(term.value).present?
    when "is" then term.value.in?(%w[unread read assigned unassigned])
    else true
    end
  end

  # in:, is:, assignee:, has:note et has:task portent sur le fil, le reste sur ses messages.
  def conversation_term?(term)
    term.operator.in?(%w[in is assignee]) || (term.operator == "has" && !term.value.in?(%w[attachment attachments pj]))
  end

  # Les messages des boîtes accessibles qui répondent aux critères d'un message, sans les mots.
  def message_scope
    mailboxes = Mailbox.accessible_by(@user)
    mailboxes = mailboxes.where(id: @mailbox) if @mailbox
    scope = Message.where(mailbox: mailboxes)
    terms.each do |term|
      next if conversation_term?(term)

      condition = message_condition(term)
      scope = term.negated ? scope.where.not(condition) : scope.where(condition)
    end
    scope
  end

  def message_condition(term)
    value = term.value
    case term.operator
    when "from"
      unaccent_like("coalesce(messages.from_name, '') || ' ' || coalesce(messages.from_address, '')", value)
    when "to" then unaccent_like("messages.to_addresses::text || ' ' || messages.cc_addresses::text", value)
    when "cc" then unaccent_like("messages.cc_addresses::text", value)
    when "subject" then unaccent_like("coalesce(messages.subject, '')", value)
    when "filename" then unaccent_like("jsonb_path_query_array(messages.attachments, '$[*].filename')::text", value)
    when "has" then { has_attachments: true }
    when "mailbox" then [ "messages.mailbox_id IN (SELECT id FROM mailboxes WHERE address ILIKE :v OR label ILIKE :v)", { v: like(value) } ]
    when "after" then [ "messages.sent_at >= ?", date(value).beginning_of_day ]
    when "before" then [ "messages.sent_at < ?", date(value).beginning_of_day ]
    when "newer_than" then [ "messages.sent_at >= ?", ago(value) ]
    when "older_than" then [ "messages.sent_at < ?", ago(value) ]
    end
  end

  def conversation_condition(term)
    conversations = Conversation.all
    case term.operator
    when "has" then conversations.where(id: (term.value.start_with?("note") ? Note : Task).select(:conversation_id))
    when "is"
      case term.value
      when "unread" then conversations.unread_for(@user)
      when "read" then conversations.where.not(id: Conversation.unread_for(@user).select(:id))
      when "assigned" then conversations.where.not(assignee_id: nil)
      when "unassigned" then conversations.where(assignee_id: nil)
      end
    when "assignee"
      return conversations.where(assignee: @user) if term.value == "me"

      conversations.where(assignee_id: User.where("users.name ILIKE :v OR users.email_address ILIKE :v", v: like(term.value)).select(:id))
    when "in" then in_condition(in_value(term.value), term.value)
    end
  end

  # La valeur d'un in: : une pile, une page, ou le début du libellé ou de l'adresse d'une boîte accessible.
  def in_value(value)
    value = IN_ALIASES.fetch(value, value)
    return value if value.in?(%w[imbox feed paper_trail screener reply_later set_aside archive sent anywhere])

    "mailbox" if Mailbox.accessible_by(@user).starting_with(value).exists?
  end

  def in_condition(name, value)
    conversations = Conversation.all
    case name
    when *Screening::BUCKETS then conversations.inbox.in_bucket_for(@user, name).outside_stacks_for(@user)
    when "screener" then conversations.screening_pending_for(@user)
    when *ConversationState::STACKS then conversations.in_stack_for(@user, name)
    when "archive" then conversations.archived_for(@user)
    when "anywhere" then conversations
    when "sent"
      conversations.where(id: Message.joins(:mailbox).where("lower(messages.from_address) = lower(mailboxes.address)").select(:conversation_id))
    when "mailbox"
      conversations.where(mailbox_id: Mailbox.starting_with(value).select(:id))
    end
  end

  # Les fils dont les notes internes et les titres de tâches, mis bout à bout, contiennent les mots.
  def annotated_ids
    Conversation.where(<<~SQL.squish, tsquery)
      conversations.id IN (SELECT annotations.conversation_id FROM (
        SELECT notes.conversation_id, notes.body AS text FROM notes
        UNION ALL SELECT tasks.conversation_id, tasks.title FROM tasks WHERE tasks.conversation_id IS NOT NULL
      ) annotations GROUP BY annotations.conversation_id
      HAVING to_tsvector('simple', public.sg_mail_unaccent(string_agg(annotations.text, ' '))) @@ to_tsquery('simple', public.sg_mail_unaccent(?)))
    SQL
  end

  def tsquery
    words.map do |word|
      expression = word.operator == :phrase ? "(#{word.value.join(' <-> ')})" : "#{word.value.first}:*"
      word.negated ? "!#{expression}" : expression
    end.join(" & ")
  end

  def unaccent_like(sql, value) = [ "public.sg_mail_unaccent(#{sql}) ILIKE public.sg_mail_unaccent(?)", like(value) ]

  def like(value) = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"

  # 2026/10/01, 2026-10-01 ou 01/10/2026.
  def date(value)
    year, month, day = case value
    when %r{\A(\d{4})[/-](\d{1,2})[/-](\d{1,2})\z} then [ $1, $2, $3 ]
    when %r{\A(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\z} then [ $3, $2, $1 ]
    end
    Time.zone.local(year.to_i, month.to_i, day.to_i) if year && Date.valid_date?(year.to_i, month.to_i, day.to_i)
  end

  def ago(value) = value.to_i.public_send(PERIODS.fetch(value[-1])).ago
end
