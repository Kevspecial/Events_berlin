# frozen_string_literal: true

module Orders
  # Cancels a paid order and refunds it. The refund is attempted *before* any
  # local state changes, so a Stripe failure leaves the order exactly as it was
  # rather than cancelling tickets the buyer was never refunded for.
  #
  # The eligibility check (paid? + cutoff) is re-verified under an
  # order-level row lock immediately before the Stripe call. The lock only
  # serialises the check-and-mutate sequence: it is released before the
  # Stripe call, so two concurrent cancel requests can still both pass the
  # check and both reach Stripe with the order still reading `paid`. What
  # actually prevents a double refund is the deterministic idempotency key
  # passed to Stripe::Refund.create below, which collapses both calls into a
  # single refund server-side.
  class CancellationService
    attr_reader :order, :reason

    def initialize(order:, reason: nil)
      @order = order
      @reason = reason
    end

    def call
      early_result = verify_cancellable
      return early_result if early_result

      refund_error = issue_refund
      return refund_error if refund_error

      apply_cancellation

      { success: true, order: order.reload }
    end

    private

    def verify_cancellable
      order.with_lock do
        next failure(:not_cancellable, 'Only paid orders can be cancelled') unless order.paid?
        next already_attended_failure if order.tickets.any?(&:checked_in?)
        next failure(:past_cutoff, cutoff_message) unless order.event.cancellable?

        nil
      end
    end

    # Someone who has been admitted at the door has consumed the thing they
    # paid for; refunding after that point is refunding a ticket that was
    # used, not one that was merely bought.
    def already_attended_failure
      failure(:already_attended, 'This order has a ticket that was already checked in and cannot be refunded')
    end

    def apply_cancellation
      ActiveRecord::Base.transaction do
        order.update!(status: 'cancelled', cancelled_at: Time.current, refund_reason: reason,
                      payment_status: 'refunded', refunded_at: Time.current)
        cancel_bookings_and_tickets
      end
    end

    # Bulk status transition on rows already known valid: the bookings and
    # tickets belong to an order just confirmed cancellable above, so
    # bypassing validations here is intentional rather than a shortcut.
    # rubocop:disable Rails/SkipsModelValidations
    def cancel_bookings_and_tickets
      order.bookings.update_all(status: 'cancelled', updated_at: Time.current)
      Ticket.where(booking_id: order.bookings.select(:id))
            .update_all(status: 'cancelled', cancelled_at: Time.current, updated_at: Time.current)
    end
    # rubocop:enable Rails/SkipsModelValidations

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def cutoff_message
      deadline = order.event.cancellable_until
      "Cancellation closed on #{deadline.strftime('%-d %B %Y at %H:%M')}"
    end

    # Returns nil on success, or a failure hash. Free orders have nothing to
    # refund and short-circuit.
    def issue_refund
      return nil if order.free? || order.stripe_payment_intent_id.blank?

      # The idempotency key, not the row lock, is what prevents a double
      # refund: if two concurrent cancels both reach Stripe for this order,
      # the shared key collapses them into a single refund and both callers
      # receive the same refund object back.
      Stripe::Refund.create(
        { payment_intent: order.stripe_payment_intent_id },
        { idempotency_key: "order-#{order.id}-refund" }
      )
      nil
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e) if defined?(Sentry)
      failure(:refund_failed, "We could not process the refund: #{e.message}")
    end
  end
end
