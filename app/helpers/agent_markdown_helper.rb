# Les réponses de l'agent sont du Markdown léger : paragraphes, listes « - » ou « 1. », **gras**, *italique*,
# `code` et liens. Tout est échappé d'abord : aucun HTML venu du modèle n'arrive tel quel dans la page.
module AgentMarkdownHelper
  LIST_ITEM = /\A\s*(?:[-*•]|(\d+)[.)])\s+(.*)\z/

  def agent_markdown(text)
    blocks = text.to_s.strip.split(/\n\s*\n/).map { |block| agent_markdown_block(block.lines.map(&:rstrip)) }
    safe_join(blocks)
  end

  private

  def agent_markdown_block(lines)
    items = lines.map { |line| line.match(LIST_ITEM) }
    return content_tag(:p, safe_join(lines.map { |line| agent_markdown_inline(line) }, tag.br)) unless items.all?

    content_tag(items.first[1] ? :ol : :ul, safe_join(items.map { |item| content_tag(:li, agent_markdown_inline(item[2])) }))
  end

  def agent_markdown_inline(line)
    html = ERB::Util.html_escape(line).to_str
    html = html.gsub(/`([^`]+)`/) { "<code>#{$1}</code>" }
    html = html.gsub(/\*\*(.+?)\*\*/) { "<strong>#{$1}</strong>" }
    html = html.gsub(/(?<![*\w])\*(?!\s)(.+?)(?<!\s)\*(?![*\w])/) { "<em>#{$1}</em>" }
    html = html.gsub(%r{\[([^\]]+)\]\((https?://[^\s)]+)\)}) { %(<a href="#{$2}" target="_blank" rel="noopener">#{$1}</a>) }
    html.html_safe # rubocop:disable Rails/OutputSafety -- tout le texte a été échappé ci-dessus
  end
end
