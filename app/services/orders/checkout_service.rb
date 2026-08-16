# frozen_string_literal: true

module Orders
  # Exchanges a pending, unexpired, non-free order for a Stripe Checkout
  # Session. One Stripe line item per Booking, so the buyer sees each tier
  # itemised on Stripe's page.
  class CheckoutService
    attr_reader :order

    def initialize(order:)
      @order = order
    end

    def call
      return failure(:not_payable, 'This order is no longer awaiting payment') unless payable?

      session = Stripe::Checkout::Session.create(session_params)
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

    def frontend_url
      ENV.fetch('FRONTEND_URL', 'http://localhost:3001')
    end

    def session_params
      {
        mode: 'payment',
        customer_email: order.user.email,
        line_items: order.bookings.map { |booking| line_item(booking) },
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
          unit_amount: (booking.ticket_type.price * 100).to_i
        },
        quantity: booking.quantity
      }
    end
  end
end
