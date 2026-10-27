# Les jetons OAuth et mots de passe IMAP sont chiffrés (Active Record Encryption).
# En production, les clés viennent des credentials ou de l'environnement.
# En local, on les dérive de secret_key_base pour que l'app démarre sans configuration.
Rails.application.configure do
  encryption = config.active_record.encryption
  keys = {
    primary_key: ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"],
    deterministic_key: ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"],
    key_derivation_salt: ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
  }.compact

  if keys.empty? && (Rails.env.development? || Rails.env.test?)
    generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
    keys = %i[primary_key deterministic_key key_derivation_salt].index_with { |name| generator.generate_key("sg_mail #{name}", 32).unpack1("H*") }
  end

  keys.each { |name, value| encryption.public_send("#{name}=", value) }
end
