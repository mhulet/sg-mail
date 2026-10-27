# Appelé par l'abonnement Pub/Sub « push » de SG Mail quand une boîte Gmail change.
# L'URL porte un secret (GMAIL_PUBSUB_TOKEN) ; le message ne dit que l'adresse et un historyId.
module Webhooks
  class GmailController < ActionController::API
    def create
      token = ENV["GMAIL_PUBSUB_TOKEN"].to_s
      return head :unauthorized if token.blank? || !ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, token)

      address = notification["emailAddress"].to_s.downcase
      mailboxes = Tenancy.across_accounts { Mailbox.where(provider: "gmail", address: address).includes(:account).to_a }
      mailboxes.each do |mailbox|
        Tenancy.with_account(mailbox.account) { SyncMailboxJob.perform_later(mailbox) }
      end
      head :no_content
    end

    private

    def notification
      JSON.parse(params.dig(:message, :data).to_s.unpack1("m"))
    rescue JSON::ParserError
      {}
    end
  end
end
