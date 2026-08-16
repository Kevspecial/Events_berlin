# frozen_string_literal: true

module Orders
  # Drives an order from pending to paid. Invoked by the Stripe webhook, which
  # Stripe may deliver more than once, so every path here is idempotent.
  #
  # An order whose 15-minute hold lapsed is still completed: the buyer's money
  # arrived, and honouring the sale is preferable to a refund. Oversell is
  # possible in that narrow window and is accepted deliberately.
  class PaymentCompletionService
    attr_reader :order, :payment_intent_id

    def initialize(order:, payment_intent_id: nil)
      @order = order
      @payment_intent_id = payment_intent_id
    end

    def call
      return { success: true, order: order } if order.paid?
      return failure(:not_completable, 'This order can no longer be paid') unless completable?

      complete!
      { success: true, order: order.reload }
    end

    private

    def complete!
      ActiveRecord::Base.transaction do
        mark_order_paid
        confirm_bookings
      end
    end

    def mark_order_paid
      order.update!(
        status: 'paid',
        payment_status: 'paid',
        paid_at: Time.current,
        stripe_payment_intent_id: payment_intent_id.presence || order.stripe_payment_intent_id
      )
    end

    def confirm_bookings
      order.bookings.find_each { |booking| booking.update!(status: 'confirmed') }
    end

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def completable?
      order.pending? || order.expired?
    end
  end
end
