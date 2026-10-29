# Les extraits des résultats de recherche, avec les mots cherchés surlignés.
module SearchesHelper
  EXCERPT_LENGTH = 220

  # Le texte, échappé, avec <mark> autour des mots qui commencent par un des mots cherchés,
  # sans tenir compte des accents ni de la casse (comme la recherche elle-même).
  def highlight_words(text, words)
    text = text.to_s
    return text if words.blank?

    ranges = match_ranges(text, words)
    return text if ranges.empty?

    position = 0
    parts = ranges.flat_map do |range|
      before = text[position...range.begin]
      position = range.end
      [ before, tag.mark(text[range]) ]
    end
    safe_join(parts << text[position..])
  end

  # Un passage du message autour du premier mot trouvé, surligné ; l'aperçu habituel sinon.
  def search_excerpt(message, words, fallback: nil)
    text = message && excerpt_source(message)
    first = text.present? && words.present? && match_ranges(text, words).first
    return fallback&.truncate(140) unless first

    start = [ first.begin - 40, 0 ].max
    start = (text.rindex(/\s/, start) || start) + (start.zero? ? 0 : 1) if start.positive?
    excerpt = text[start, EXCERPT_LENGTH]
    safe_join([ ("… " if start.positive?), highlight_words(excerpt, words), ("…" if start + EXCERPT_LENGTH < text.length) ].compact)
  end

  private

  def excerpt_source(message)
    text = message.body_text.presence || (message.body_html.present? && Nokogiri::HTML(message.body_html.first(400_000)).text)
    text.to_s.first(20_000).squish
  end

  # Les plages du texte qui commencent par un des mots, en début de mot. La comparaison se fait sur une
  # version sans accents de même longueur, pour que les positions restent celles du texte d'origine.
  def match_ranges(text, words)
    folded = fold(text)
    pattern = /(?<![\p{L}\p{N}])(?:#{words.map { |word| Regexp.escape(fold(word)) }.join("|")})[\p{L}\p{N}]*/
    folded.to_enum(:scan, pattern).map { Regexp.last_match.begin(0)...Regexp.last_match.end(0) }
  end

  def fold(text) = text.each_char.map { |char| char.unicode_normalize(:nfd)[0].downcase[0] }.join
end
