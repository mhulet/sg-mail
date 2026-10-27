namespace :sg_mail do
  desc "Synchronise toutes les boîtes une fois"
  task sync: :environment do
    Mailbox.find_each do |mailbox|
      print "#{mailbox.address}… "
      mailbox.sync!
      puts "#{mailbox.messages.count} messages"
    rescue => e
      puts "erreur : #{e.class}: #{e.message}"
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
