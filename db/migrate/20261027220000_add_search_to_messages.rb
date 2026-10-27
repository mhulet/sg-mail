# Recherche plein texte dans les messages : une colonne tsvector calculée par Postgres,
# sans accents (« ete » trouve « été ») et sans dictionnaire de langue (FR, NL et EN mélangés).
class AddSearchToMessages < ActiveRecord::Migration[8.1]
  def up
    enable_extension "unaccent"
    # unaccent() n'est pas IMMUTABLE : on l'enveloppe pour pouvoir l'utiliser dans une colonne calculée.
    execute <<~SQL
      CREATE FUNCTION public.sg_mail_unaccent(text) RETURNS text
        LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
        AS $$ SELECT public.unaccent('public.unaccent'::regdictionary, $1) $$;
    SQL

    # Le corps est tronqué : un tsvector ne dépasse pas 1 Mo. Sans partie texte, on retire les balises du HTML.
    execute <<~SQL
      ALTER TABLE messages ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('simple', public.sg_mail_unaccent(coalesce(subject, ''))), 'A') ||
        setweight(to_tsvector('simple', public.sg_mail_unaccent(coalesce(from_name, '') || ' ' || coalesce(from_address, ''))), 'B') ||
        setweight(to_tsvector('simple', public.sg_mail_unaccent(to_addresses::text || ' ' || cc_addresses::text)), 'C') ||
        setweight(to_tsvector('simple', public.sg_mail_unaccent(left(coalesce(body_text,
          regexp_replace(left(body_html, 400000), '<[^>]*>', ' ', 'g'), ''), 200000))), 'D')
      ) STORED
    SQL
    add_index :messages, :search_vector, using: :gin
  end

  def down
    remove_column :messages, :search_vector
    execute "DROP FUNCTION public.sg_mail_unaccent(text)"
    disable_extension "unaccent"
  end
end
