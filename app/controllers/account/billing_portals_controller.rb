class Account::BillingPortalsController < ApplicationController
  before_action :ensure_admin
  before_action :ensure_subscribed_account

  def show
    session = Stripe::BillingPortal::Session.create(customer: Current.account.subscription.stripe_customer_id, return_url: account_settings_url)
    redirect_to session.url, allow_other_host: true
  end

  private
    def ensure_subscribed_account
      unless Current.account.subscribed?
        redirect_to account_subscription_path, alert: "No billing information found"
      end
    end
end
