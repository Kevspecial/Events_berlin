# frozen_string_literal: true

Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key) || ENV.fetch('STRIPE_SECRET_KEY', nil)

# Webhook signing secret for validating webhook events
Rails.application.config.stripe_webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret) ||
                                                 ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)
