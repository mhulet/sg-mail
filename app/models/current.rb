class Current < ActiveSupport::CurrentAttributes
  attribute :session, :membership
  delegate :user, to: :session, allow_nil: true
  delegate :account, to: :membership, allow_nil: true
end
