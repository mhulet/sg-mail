# La recherche trouve aussi les noms des pièces jointes : « devis » trouve « Devis-jardin-2026.pdf ».
# Une colonne calculée ne se modifie pas : on la recrée, Postgres recalcule chaque ligne.
class AddAttachmentNamesToSearch < ActiveRecord::Migration[8.1]
  BODY = "left(coalesce(body_text, regexp_replace(left(body_html, 400000), '<[^>]*>', ' ', 'g'), ''), 200000)"
  HEAD = <<~SQL.freeze
    setweight(to_tsvector('simple', public.sg_mail_unaccent(coalesce(subject, ''))), 'A') ||
    setweight(to_tsvector('simple', public.sg_mail_unaccent(coalesce(from_name, '') || ' ' || coalesce(from_address, ''))), 'B') ||
    setweight(to_tsvector('simple', public.sg_mail_unaccent(to_addresses::text || ' ' || cc_addresses::text)), 'C') ||
  SQL

  def up
    recreate(<<~SQL)
      #{HEAD}
      setweight(to_tsvector('simple', regexp_replace(public.sg_mail_unaccent(
        jsonb_path_query_array(attachments, '$[*].filename')::text), '[^[:alnum:]]+', ' ', 'g')), 'C') ||
      setweight(to_tsvector('simple', public.sg_mail_unaccent(#{BODY})), 'D')
    SQL
  end

  def down
    recreate("#{HEAD} setweight(to_tsvector('simple', public.sg_mail_unaccent(#{BODY})), 'D')")
  end

  private

  def recreate(expression)
    remove_column :messages, :search_vector
    execute "ALTER TABLE messages ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (#{expression}) STORED"
    add_index :messages, :search_vector, using: :gin
  end
end
