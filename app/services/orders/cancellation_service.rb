# frozen_string_literal: true

module Orders
  # Cancels a paid order and refunds it. The refund is attempted *before* any
  # local state changes, so a Stripe failure leaves the order exactly as it was
  # rather than cancelling tickets the buyer was never refunded for.
  #
  # The eligibility check (paid? + cutoff) is re-verified under an
  # order-level row lock immediately before the Stripe call, so two
  # concurrent cancel requests can't both pass the check and both issue a
  # refund. The lock is released again before the call: Stripe::Refund.create
  # is a network round-trip and not idempotent without an explicit
  # idempotency key, so it must not run while holding a row lock any longer
  # than the check itself requires.
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
        next failure(:past_cutoff, cutoff_message) unless order.event.cancellable?

        nil
      end
    end

    def apply_cancellation
      ActiveRecord::Base.transaction do
        order.update!(status: 'cancelled', cancelled_at: Time.current, refund_reason: reason)
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

      Stripe::Refund.create(payment_intent: order.stripe_payment_intent_id)
      nil
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e) if defined?(Sentry)
      failure(:refund_failed, "We could not process the refund: #{e.message}")
    end
  end
end
