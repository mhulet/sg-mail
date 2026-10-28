# Les aperçus importés de Gmail gardaient leurs entités HTML (J&#39;ai, &quot;…&quot;) : on les décode.
class UnescapeSnippets < ActiveRecord::Migration[8.1]
  def up
    execute "SET sg_mail.bypass_rls = 'on'"
    %w[messages conversations].each do |table|
      select_rows("SELECT id, snippet FROM #{table} WHERE snippet ~ '&(#[0-9]+|#x[0-9a-fA-F]+|[a-zA-Z]+);'").each do |id, snippet|
        decoded = MessageParser.snippet(snippet)
        next if decoded == snippet

        execute "UPDATE #{table} SET snippet = #{quote(decoded)} WHERE id = #{id.to_i}"
      end
    end
  ensure
    execute "RESET sg_mail.bypass_rls"
  end

  def down; end
end
