class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "SG Mail <sg-mail@supergenial.be>")
  layout "mailer"
end
