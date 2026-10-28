require "thor"

module SgMail
  # Commandes de « sg-mail ». --json donne la réponse brute de l'API (pratique pour Claude Code).
  class Cli < Thor
    class_option :json, type: :boolean, desc: "Sortie JSON brute"

    def self.exit_on_failure? = true

    # Client injecté par les tests ; sinon lu dans la configuration.
    class << self
      attr_accessor :client
    end

    desc "login URL JETON", "Enregistre l'adresse de SG Mail et un jeton personnel"
    def login(url, token)
      Client.save_config(url, token)
      me = Client.new(url, token).get("me")
      say "Connecté : #{me.dig("user", "name")} chez #{me.dig("account", "name")}."
    end

    desc "me", "Qui suis-je, mes boîtes et mes collègues"
    def me
      output(client.get("me")) do |data|
        say "#{data.dig("user", "name")} <#{data.dig("user", "email")}> · #{data.dig("account", "name")}"
        data["mailboxes"].each { |m| say "  boîte #{m["id"]} : #{m["address"]} (#{m["access"]})" }
        data["members"].each { |u| say "  membre #{u["id"]} : #{u["name"]}" }
      end
    end

    desc "inbox", "Réception (--box feed ou paper_trail pour les autres piles, --mailbox pour une boîte)"
    option :box, enum: %w[imbox feed paper_trail]
    option :unread, type: :boolean, desc: "Non lus seulement"
    option :mine, type: :boolean, desc: "Assignés à moi"
    option :mailbox, type: :numeric
    option :limit, type: :numeric, default: 30
    def inbox
      list_conversations(nil)
    end

    desc "feed", "Le Feed : lettres d'info et lectures"
    option :unread, type: :boolean
    option :limit, type: :numeric, default: 30
    def feed = list_conversations(nil, box: "feed")

    desc "paper-trail", "Le Paper Trail : reçus, confirmations, notifications"
    option :unread, type: :boolean
    option :limit, type: :numeric, default: 30
    def paper_trail = list_conversations(nil, box: "paper_trail")

    desc "search REQUÊTE", "Recherche (filtres : de:anne a:formations avec:pj)"
    option :mailbox, type: :numeric
    option :limit, type: :numeric, default: 30
    def search(*words)
      list_conversations(words.join(" "))
    end

    desc "show ID", "Affiche un fil (--read le marque comme lu)"
    option :read, type: :boolean
    def show(id)
      output(client.get("conversations/#{int(id)}", mark_read: options[:read] ? 1 : nil)) do |data|
        c = data["conversation"]
        say "#{c["subject"]}  [#{c["mailbox"]}]#{"  → #{c.dig("assignee", "name")}" if c["assignee"]}"
        say c["url"]
        c["messages"].each do |m|
          say "\n── message #{m["id"]} · #{m.dig("from", "name") || m.dig("from", "address")} <#{m.dig("from", "address")}> · #{m["sent_at"]}"
          say "   lu par : #{m["read_by"].join(", ").then { |s| s.empty? ? "personne" : s }}"
          m["attachments"].each { |a| say "   📎 #{a["filename"]}" }
          say m["body"].to_s.strip
        end
        c["notes"].each { |n| say "\n📝 #{n["author"]} : #{n["body"]}" }
        c["tasks"].each { |t| say "☐ #{task_line(t)}" }
      end
    end

    desc "read ID", "Marque un fil comme lu (pour moi seulement)"
    def read(id) = done(client.post("conversations/#{int(id)}/read"), "Fil #{id} marqué comme lu.")

    desc "unread ID", "Marque un fil comme non lu"
    def unread(id) = done(client.post("conversations/#{int(id)}/unread"), "Fil #{id} marqué comme non lu.")

    desc "assign ID MEMBRE|none", "Confie un fil à quelqu'un (id donné par « sg-mail me »)"
    def assign(id, member)
      data = client.patch("conversations/#{int(id)}", assignee_id: member == "none" ? "" : member)
      done(data, data.dig("conversation", "assignee") ? "Confié à #{data.dig("conversation", "assignee", "name")}." : "Plus assigné.")
    end

    desc "screener", "À trier : les nouveaux expéditeurs qui attendent ma décision"
    def screener
      output(client.get("screener")) do |data|
        say "Personne n'attend." if data["pending"].empty?
        data["pending"].each do |s|
          c = s["latest_conversation"]
          say format("%-32s %-22.22s %s%s", s["address"], s["name"].to_s, c["subject"],
            s["conversations_count"] > 1 ? "  (#{s["conversations_count"]} fils)" : "")
        end
        data["blocked"].each { |b| say "bloqué : #{b["address"]}" }
      end
    end

    desc "accept ADRESSE", "Accepte un expéditeur (--to feed ou paper_trail ; sert aussi à le déplacer)"
    option :to, enum: %w[imbox feed paper_trail]
    def accept(address)
      data = client.post("screener", address: address, decision: "accepted", box: options[:to])
      done(data, "#{address} accepté, dans #{data.dig("screening", "box")}.")
    end

    desc "block ADRESSE", "Bloque un expéditeur : ses emails restent hors de ma réception"
    def block(address) = screen(address, "blocked", "#{address} bloqué.")

    desc "note ID TEXTE", "Ajoute une note interne à un fil"
    def note(id, *text) = done(client.post("conversations/#{int(id)}/notes", body: text.join(" ")), "Note ajoutée.")

    desc "tasks", "Mes tâches à faire (--all : toutes, --done : terminées)"
    option :all, type: :boolean
    option :done, type: :boolean
    def tasks
      data = client.get("tasks", scope: options[:all] ? "all" : "mine", status: options[:done] ? "done" : "open")
      output(data) { |d| d["tasks"].empty? ? say("Rien à faire.") : d["tasks"].each { |t| say task_line(t) } }
    end

    desc "task-add TITRE", "Crée une tâche (--message ID pour la lier à un email)"
    option :message, type: :numeric
    option :conversation, type: :numeric
    option :due, desc: "AAAA-MM-JJ"
    option :to, desc: "id du membre, ou none"
    def task_add(*title)
      body = { title: title.join(" "), message_id: options[:message], conversation_id: options[:conversation], due_on: options[:due] }
      body[:assignee_id] = options[:to] == "none" ? "" : options[:to] if options[:to]
      data = client.post("tasks", body)
      done(data, "Tâche créée : #{task_line(data["task"])}")
    end

    desc "task-done ID", "Termine une tâche"
    def task_done(id) = done(client.patch("tasks/#{int(id)}", status: "done"), "Tâche #{id} terminée.")

    desc "reply MESSAGE_ID [TEXTE]", "Prépare une réponse (brouillon, jamais envoyée). Sans texte : lu sur l'entrée standard"
    option :all, type: :boolean, desc: "Répondre à tous"
    def reply(message_id, *text)
      draft_from(message_id, options[:all] ? "reply_all" : "reply", text)
    end

    desc "forward MESSAGE_ID --to ADRESSE [TEXTE]", "Prépare un transfert (brouillon)"
    option :to, type: :array, required: true
    def forward(message_id, *text)
      draft_from(message_id, "forward", text, to: options[:to])
    end

    desc "drafts", "Mes brouillons"
    def drafts
      output(client.get("drafts")) do |data|
        data["drafts"].each { |d| say "#{d["id"]}  #{d["status"]}  #{d["subject"]}  → #{d["to"].join(", ")}" }
      end
    end

    desc "send BROUILLON_ID", "Envoie un brouillon (demande confirmation, sauf --yes)"
    option :yes, type: :boolean
    def send_draft(id)
      draft = client.get("drafts/#{int(id)}")["draft"]
      unless options[:yes] || yes?("Envoyer « #{draft["subject"]} » à #{draft["to"].join(", ")} depuis #{draft["mailbox"]} ? (y/N)")
        return say("Pas envoyé.")
      end

      done(client.post("drafts/#{int(id)}/deliver"), "Envoi en cours.")
    end
    map "send" => :send_draft

    private

    def client = @client ||= self.class.client || Client.from_config

    def int(value) = Integer(value, exception: false) || raise(Client::Error, "Identifiant attendu (un nombre), reçu : #{value.inspect}")

    def list_conversations(query, box: options[:box])
      data = client.get("conversations", q: query, box: box, unread: options[:unread] ? 1 : nil, mine: options[:mine] ? 1 : nil,
        mailbox_id: options[:mailbox], limit: options[:limit])
      output(data) do |d|
        say "Rien ici." if d["conversations"].empty?
        d["conversations"].each do |c|
          say format("%s %-7s %-22.22s %s%s", c["unread"] ? "●" : " ", c["id"], c["last_sender"].to_s, c["subject"],
            c["assignee"] ? "  → #{c.dig("assignee", "name")}" : "")
        end
      end
    end

    def screen(address, decision, message) = done(client.post("screener", address: address, decision: decision), message)

    def draft_from(message_id, kind, text, to: nil)
      body = text.any? ? text.join(" ") : ($stdin.tty? ? nil : $stdin.read)
      data = client.post("drafts", message_id: int(message_id), kind: kind, body: body && "#{body.rstrip}\n", to: to)
      done(data, "Brouillon #{data.dig("draft", "id")} prêt (pas envoyé) : #{data.dig("draft", "url")}\n" \
        "Pour l'envoyer : sg-mail send #{data.dig("draft", "id")}")
    end

    def task_line(task)
      [ "#{task["id"]}.", task["title"], task["assignee"] && "· #{task.dig("assignee", "name")}",
        task["due_on"] && "· pour le #{task["due_on"]}#{" (en retard)" if task["overdue"]}",
        task["conversation_id"] && "· fil #{task["conversation_id"]}" ].compact.join(" ")
    end

    def output(data)
      options[:json] ? say(JSON.pretty_generate(data)) : yield(data)
    end

    def done(data, message) = output(data) { say message }
  end
end
