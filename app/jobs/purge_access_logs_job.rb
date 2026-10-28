class PurgeAccessLogsJob < ApplicationJob
  queue_as :default

  def perform
    Tenancy.across_accounts { AccessLog.purge_old! }
  end
end
