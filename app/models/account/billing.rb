module Account::Billing
  extend ActiveSupport::Concern

  included do
    has_one :subscription, class_name: "Account::Subscription", dependent: :destroy
  end

  # TODO: Delete when the storage tracking system is in place
  def bytes_used
    500.megabytes
  end

  def plan
    active_subscription&.plan || Plan.free
  end

  def active_subscription
    subscription if subscription&.active?
  end

  def subscribed?
    subscription&.stripe_customer_id.present?
  end

  def limits_exceeded?
    card_limit_exceeded? || storage_limit_exceeded?
  end

  def card_limit_exceeded?
    cards_count > plan.card_limit
  end

  def storage_limit_exceeded?
    bytes_used > plan.storage_limit
  end
end
