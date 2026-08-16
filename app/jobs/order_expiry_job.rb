# frozen_string_literal: true

# Sweeps orders whose 15-minute payment hold lapsed. Expiring an order is what
# releases its inventory back to the pool — Order.holding_inventory already
# ignores lapsed rows, so this job is bookkeeping that makes the state visible
# and cascades the change to bookings.
class OrderExpiryJob < ApplicationJob
  queue_as :default

  def perform
    count = 0

    Order.sweepable.find_each do |order|
      ActiveRecord::Base.transaction do
        order.update!(status: 'expired')
        # Bypassing validations is deliberate: these bookings were valid when
        # created, this is a pure status transition, and a sweeper must not be
        # blockable by a single bad row.
        # rubocop:disable Rails/SkipsModelValidations
        order.bookings.update_all(status: 'cancelled', updated_at: Time.current)
        # rubocop:enable Rails/SkipsModelValidations
      end
      report_abandoned_session(order)
      count += 1
    end

    count
  end

  private

  # An order that reached Stripe but never came back means either the buyer
  # walked away or a webhook was lost. The two are indistinguishable from here,
  # so this is a warning rather than an error — but a spike in these is the
  # first sign that webhook delivery is broken.
  def report_abandoned_session(order)
    return if order.stripe_checkout_session_id.blank?

    message = "Order #{order.id} expired with an unconsumed Stripe session " \
              "#{order.stripe_checkout_session_id}"
    Rails.logger.warn(message)
    Sentry.capture_message(message, level: :warning) if defined?(Sentry)
  end
end
