# Import puis synchro incrémentale d'une boîte IMAP.
#
# Par dossier : reprise sur le dernier UID connu, remise à zéro si
# UIDVALIDITY change. Lecture avec EXAMINE et BODY.PEEK pour ne jamais
# toucher au drapeau \Seen du serveur (décision D4).
class ImapSync
  FETCH_SIZE = 50

  def self.connect(credentials)
    imap = Net::IMAP.new(credentials["host"], port: credentials["port"].presence&.to_i || 993, ssl: credentials["ssl"] != false)
    imap.login(credentials["username"], credentials["password"])
    imap
  end

  def initialize(mailbox, import_limit: ENV["IMAP_IMPORT_LIMIT"].presence&.to_i)
    @mailbox = mailbox
    @import_limit = import_limit
  end

  def call
    imap = self.class.connect(mailbox.credentials)
    folder_names(imap).each { |name| sync_folder(imap, name) }
  ensure
    imap&.logout rescue nil
    imap&.disconnect rescue nil
  end

  private

  attr_reader :mailbox

  # INBOX et le dossier Envoyés (attribut SPECIAL-USE \Sent quand le serveur le donne).
  def folder_names(imap)
    lists = imap.list("", "*") || []
    sent = lists.find { |l| l.attr.include?(:Sent) } ||
      lists.find { |l| l.name.match?(/\A(INBOX[.\/])?(Sent|Envoy)/i) }
    [ "INBOX", sent&.name ].compact.uniq
  end

  def sync_folder(imap, name)
    folder = mailbox.mail_folders.find_or_create_by!(name: name)
    status = imap.status(name, %w[UIDVALIDITY])
    uidvalidity = status["UIDVALIDITY"]

    if folder.uidvalidity != uidvalidity
      folder.messages.delete_all
      folder.update!(uidvalidity: uidvalidity, last_uid: 0)
    end

    imap.examine(name)
    remove_expunged(imap, folder)

    uids = imap.uid_search([ "UID", "#{folder.last_uid + 1}:*" ]).select { |uid| uid > folder.last_uid }.sort
    uids = uids.last(@import_limit) if @import_limit && folder.last_uid.zero?

    uids.each_slice(FETCH_SIZE) do |slice|
      Array(imap.uid_fetch(slice, %w[UID FLAGS BODY.PEEK[]])).each { |data| store(folder, data) }
      folder.update!(last_uid: slice.max)
    end
  end

  def remove_expunged(imap, folder)
    return if folder.last_uid.zero?

    present = imap.uid_search([ "UID", "1:#{folder.last_uid}" ]).to_set
    stale = folder.messages.pluck(:id, :provider_uid).reject { |_id, uid| present.include?(uid.split("/").last.to_i) }
    folder.messages.where(id: stale.map(&:first)).delete_all if stale.any?
  end

  def store(folder, data)
    uid = data.attr["UID"]
    message = mailbox.messages.find_or_initialize_by(provider_uid: "#{folder.name}/#{folder.uidvalidity}/#{uid}")
    message.assign_attributes(MessageParser.parse(data.attr["BODY[]"]))
    message.mail_folder = folder
    message.labels = Array(data.attr["FLAGS"]).map(&:to_s)
    message.save!
  end
end
