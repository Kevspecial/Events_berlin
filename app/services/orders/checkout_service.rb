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

    # If the order already points at a Stripe session, decide what to do with
    # it based on its status rather than assuming it is still usable:
    #
    # * 'open'     — still awaiting payment; reuse it instead of minting a
    #                second live session for the same order.
    # * 'complete' — the buyer already paid. The order can still be 'pending'
    #                here because the checkout.session.completed webhook may
    #                not have landed yet (queue lag, retries, a resubmit).
    #                Refuse rather than hand out a second payment link.
    # * 'expired'  — the buyer abandoned it; a fresh session is fine.
    #
    # An id Stripe no longer recognises (e.g. stale test data) is treated the
    # same as having no session at all.
    def reusable_session
      id = order.stripe_checkout_session_id
      return nil if id.blank?

      existing = Stripe::Checkout::Session.retrieve(id)
      status_to_result(existing)
    rescue Stripe::InvalidRequestError
      nil
    end

    def status_to_result(existing)
      case existing.status
      when 'open'
        existing
      when 'complete'
        failure(:payment_in_progress,
                'This order has already been paid. Its confirmation is still processing.')
      end
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
    #
    # Exact equality is the wrong test, though: each line item's unit_amount
    # is rounded independently, while order.total_amount is rounded once, so
    # the two are only guaranteed to agree while total_price divides evenly
    # into whole cents by quantity. Any future discount, proration, or manual
    # adjustment can make them diverge by a cent or two per unit even though
    # the order is perfectly valid — and since nothing about the stored order
    # changes on retry, refusing outright would permanently block payment.
    # Allow up to a cent of drift per unit; anything beyond that is real data
    # drift, not rounding noise.
    def amounts_reconcile?(items)
      items_total_cents = items.sum { |item| item[:price_data][:unit_amount] * item[:quantity] }
      order_total_cents = (order.total_amount * 100).round
      gap = (items_total_cents - order_total_cents).abs
      return false if gap > reconciliation_tolerance_cents

      log_rounding_gap(items_total_cents, order_total_cents) if gap.positive?
      true
    end

    # Each unit's price is rounded to whole cents independently, so a booking of
    # N units can drift up to N/2 cents from the order's stored total through
    # rounding alone. Allow a cent per unit: generous enough that legitimate
    # rounding never blocks a sale, tight enough that real drift — which would
    # be euros, not cents — still refuses to charge.
    def reconciliation_tolerance_cents
      order.bookings.sum(:quantity)
    end

    def log_rounding_gap(items_total_cents, order_total_cents)
      message = "Order #{order.id} checkout rounding gap: line items total " \
                "#{items_total_cents}c vs order total #{order_total_cents}c"
      Rails.logger.warn(message)
      Sentry.capture_message(message, level: :warning) if defined?(Sentry)
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
