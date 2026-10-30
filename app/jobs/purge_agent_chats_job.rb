class PurgeAgentChatsJob < ApplicationJob
  queue_as :default

  def perform
    Tenancy.across_accounts { AgentChat.purge_old! }
  end
end
