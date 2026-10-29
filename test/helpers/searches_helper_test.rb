require "test_helper"

class SearchesHelperTest < ActionView::TestCase
  Body = Struct.new(:body_text, :body_html, keyword_init: true)

  test "highlights words by prefix, without accents or case, and escapes the rest" do
    assert_equal "<mark>Inscription</mark> formation d&#39;<mark>été</mark> &lt;b&gt;",
      highlight_words("Inscription formation d'été <b>", %w[inscri ete])
    assert_equal "préinscription", highlight_words("préinscription", %w[inscri]), "en début de mot seulement"
  end

  test "an excerpt around the first match, from the HTML when there is no text part" do
    message = Body.new(body_html: "<p>#{'Bla bla. ' * 30}Voici le <b>devis</b> pour la forêt.#{' Fin.' * 60}</p>")
    excerpt = search_excerpt(message, %w[devis foret])
    assert_match %r{\A… .*Voici le <mark>devis</mark> pour la <mark>forêt</mark>\..*…\z}, excerpt
    assert_operator excerpt.length, :<, 320
    assert_equal "Aperçu", search_excerpt(nil, %w[devis], fallback: "Aperçu")
    assert_equal "Aperçu", search_excerpt(Body.new(body_text: "Rien"), %w[devis], fallback: "Aperçu")
  end
end
