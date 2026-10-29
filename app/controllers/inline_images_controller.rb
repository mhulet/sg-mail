# Images intégrées au corps d'un message (<img src="cid:…">). Le corps s'affiche dans un cadre en bac à sable,
# d'une autre origine : le navigateur n'y envoie pas le cookie de session. Chaque image a donc une adresse
# signée, valable un jour, faite pour la personne qui a ouvert le fil (voir MessagesHelper#message_body_html).
class InlineImagesController < ApplicationController
  include AttachmentServing
  allow_unauthenticated_access

  def self.token_for(message, content_id)
    verifier.generate({ "account" => message.account_id, "message" => message.id, "cid" => content_id }, expires_in: 1.day)
  end

  def self.verifier = Rails.application.message_verifier("inline-image")

  def show
    data = self.class.verifier.verified(params[:token]) or raise ActiveRecord::RecordNotFound

    Tenancy.with_account(Account.find(data["account"])) do
      message = Message.find(data["message"])
      blob = AttachmentCache.new(message).inline_blob(data["cid"])
      raise ActiveRecord::RecordNotFound unless blob && blob.content_type.in?(VIEWABLE_IMAGES)

      serve_inline(blob)
    end
  end
end
