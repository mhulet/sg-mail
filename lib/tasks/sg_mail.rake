namespace :sg_mail do
  desc "Crée (ou complète) un compte de l'équipe Super Génial : EMAIL=… NAME=… [PASSWORD=…]"
  task staff: :environment do
    email = ENV.fetch("EMAIL") { abort "EMAIL manquant" }
    password = ENV["PASSWORD"].presence || SecureRandom.base58(16)
    user = User.find_or_initialize_by(email_address: email)
    user.name = ENV["NAME"].presence || user.name.presence || email
    user.password = password if user.new_record? || ENV["PASSWORD"].present?
    user.staff = true
    user.save!
    puts "#{user.email_address} fait partie de l'équipe Super Génial."
    puts "Mot de passe : #{password}" if user.saved_change_to_password_digest?

    # Phase 0 : les boîtes déjà importées sont dans un client sans membre ; on y rattache ce compte.
    Account.where.missing(:memberships).find_each do |account|
      account.memberships.create!(user: user, role: "admin")
      puts "Admin de « #{account.name} »."
    end
  end

  desc "Synchronise toutes les boîtes une fois"
  task sync: :environment do
    Tenancy.across_accounts do
      Mailbox.includes(:account).find_each do |mailbox|
        Tenancy.with_account(mailbox.account) do
          print "#{mailbox.account.name} · #{mailbox.address}… "
          mailbox.sync!
          puts "#{mailbox.messages.count} messages"
        rescue => e
          puts "erreur : #{e.class}: #{e.message}"
        end
      end
    end
  end

  desc "Synchronise toutes les boîtes en boucle (INTERVAL secondes, 60 par défaut)"
  task watch: :environment do
    interval = ENV.fetch("INTERVAL", 60).to_i
    loop do
      Rake::Task["sg_mail:sync"].reenable
      Rake::Task["sg_mail:sync"].invoke
      sleep interval
    end
  end
end
