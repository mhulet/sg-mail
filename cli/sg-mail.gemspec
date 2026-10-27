require_relative "lib/sg_mail/version"

Gem::Specification.new do |spec|
  spec.name = "sg-mail"
  spec.version = SgMail::VERSION
  spec.summary = "CLI de SG Mail : réception, fils, tâches et brouillons depuis le terminal"
  spec.authors = [ "Super Génial" ]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*.rb", "exe/*"]
  spec.bindir = "exe"
  spec.executables = [ "sg-mail" ]
  spec.add_dependency "thor", ">= 1.2"
end
