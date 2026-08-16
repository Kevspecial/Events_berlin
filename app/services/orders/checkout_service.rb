# frozen_string_literal: true

module Orders
  # Exchanges a pending, unexpired, non-free order for a Stripe Checkout
  # Session. One Stripe line item per Booking, so the buyer sees each tier
  # itemised on Stripe's page.
  class CheckoutService
    attr_reader :order

    AMOUNT_MISMATCH_MESSAGE =
      'Order line items do not match the order total; refusing to charge an unconfirmed amount'

    def initialize(order:)
      @order = order
    end

    def call
      return failure(:not_payable, 'This order is no longer awaiting payment') unless payable?

      session = reusable_session || create_fresh_session
      return session if session.is_a?(Hash)

      order.update!(stripe_checkout_session_id: session.id)
      { success: true, checkout_url: session.url, session_id: session.id }
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e) if defined?(Sentry)
      failure(:stripe_error, e.message)
    end

    private

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def payable?
      order.pending? && !order.free? && order.expires_at > Time.current
    end

    # If the order already points at a Stripe session, reuse it rather than
    # minting a second live session for the same order (which would let a
    # buyer pay twice). Only a still-open session is reusable; a completed or
    # expired one falls through to create_fresh_session. An id Stripe no
    # longer recognises (e.g. stale test data) is treated the same as having
    # no session at all.
    def reusable_session
      id = order.stripe_checkout_session_id
      return nil if id.blank?

      existing = Stripe::Checkout::Session.retrieve(id)
      existing if existing.status == 'open'
    rescue Stripe::InvalidRequestError
      nil
    end

    def create_fresh_session
      items = line_items
      return failure(:amount_mismatch, AMOUNT_MISMATCH_MESSAGE) unless amounts_reconcile?(items)

      Stripe::Checkout::Session.create(session_params(items))
    end

    def frontend_url
      ENV.fetch('FRONTEND_URL', 'http://localhost:3001')
    end

    def line_items
      order.bookings.map { |booking| line_item(booking) }
    end

    # Last line of defence: the per-booking prices are frozen at order
    # creation, and order.total_amount is frozen alongside them. If the two
    # have drifted apart (e.g. a data bug, a manual edit) we refuse to create
    # a session rather than risk charging the buyer an amount they never
    # agreed to.
    def amounts_reconcile?(items)
      items_total_cents = items.sum { |item| item[:price_data][:unit_amount] * item[:quantity] }
      items_total_cents == (order.total_amount * 100).round
    end

    def session_params(items)
      {
        mode: 'payment',
        customer_email: order.user.email,
        line_items: items,
        metadata: { order_id: order.id, user_id: order.user_id },
        success_url: success_url,
        cancel_url: cancel_url
      }
    end

    def success_url
      "#{frontend_url}/checkout/success?order_id=#{order.id}&session_id={CHECKOUT_SESSION_ID}"
    end

    def cancel_url
      "#{frontend_url}/checkout/cancel?order_id=#{order.id}"
    end

    def line_item(booking)
      {
        price_data: {
          currency: order.currency,
          product_data: {
            name: "#{booking.event.name} — #{booking.ticket_type.name}",
            metadata: { event_id: booking.event_id, ticket_type_id: booking.ticket_type_id }
          },
          unit_amount: (booking.total_price / booking.quantity * 100).round
        },
        quantity: booking.quantity
      }
    end
  end
end
