# frozen_string_literal: true

module Api
  module V1
    class CheckoutController < BaseController
      skip_before_action :authenticate_user!, only: [:webhook]
      skip_before_action :verify_authenticity_token, only: [:webhook], raise: false

      # POST /api/v1/checkout/webhook
      # Handles Stripe webhook events
      def webhook
        payload = request.body.read
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        endpoint_secret = Rails.application.config.stripe_webhook_secret

        begin
          event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
        rescue JSON::ParserError
          return render json: { error: 'Invalid payload' }, status: :bad_request
        rescue Stripe::SignatureVerificationError
          return render json: { error: 'Invalid signature' }, status: :bad_request
        end

        handle_webhook_event(event)
        render json: { received: true }
      end

      private

      def handle_webhook_event(event)
        case event.type
        when 'checkout.session.completed'
          complete_order(event.data.object)
        when 'charge.refunded'
          record_refund(event.data.object)
        end
      end

      def complete_order(session)
        order = find_order_for(session)
        return if order.nil?

        warn_on_session_mismatch(order, session)

        Orders::PaymentCompletionService.new(
          order: order,
          payment_intent_id: session.respond_to?(:payment_intent) ? session.payment_intent : nil
        ).call
      end

      # A completed session whose id doesn't match the order's stored session
      # id means a second, unlinked Stripe session was created and paid for
      # the same order — the signature of a double-charged buyer. This must
      # never pass silently.
      def warn_on_session_mismatch(order, session)
        stored_id = order.stripe_checkout_session_id
        return if stored_id.blank? || stored_id == session.id

        message = "Order #{order.id} completed with session #{session.id} but had #{stored_id} on record"
        Rails.logger.warn(message)
        Sentry.capture_message(message, level: :warning) if defined?(Sentry)
      end

      def record_refund(charge)
        intent = charge.respond_to?(:payment_intent) ? charge.payment_intent : nil
        return if intent.blank?

        order = Order.find_by(stripe_payment_intent_id: intent)
        return if order.nil? || order.refunded?

        return record_partial_refund(order, charge) unless full_refund?(charge)

        ActiveRecord::Base.transaction do
          order.update!(
            status: 'refunded',
            payment_status: 'refunded',
            refunded_at: Time.current,
            cancelled_at: order.cancelled_at || Time.current
          )
          void_tickets_for(order)
        end
      end

      # Stripe fires charge.refunded for partial refunds too. A goodwill
      # refund of part of the order must not cancel every ticket on it, so
      # only cascade when the refunded amount equals the charge amount.
      def full_refund?(charge)
        amount = charge.respond_to?(:amount) ? charge.amount : nil
        amount_refunded = charge.respond_to?(:amount_refunded) ? charge.amount_refunded : nil
        return true if amount.nil? || amount_refunded.nil?

        amount_refunded >= amount
      end

      def record_partial_refund(order, charge)
        message = "Order #{order.id} received a partial refund: #{charge.amount_refunded}/#{charge.amount}"
        Rails.logger.info(message)
        order.update!(refund_reason: message) if order.refund_reason.blank?
      end

      # A refunded order's tickets must be voided so they stop scanning at
      # the door, and a validation failure on that bulk transition must not
      # block the refund from being recorded.
      # rubocop:disable Rails/SkipsModelValidations
      def void_tickets_for(order)
        order.bookings.update_all(status: 'cancelled', updated_at: Time.current)
        Ticket.where(booking_id: order.bookings.select(:id))
              .update_all(status: 'cancelled', cancelled_at: Time.current, updated_at: Time.current)
      end
      # rubocop:enable Rails/SkipsModelValidations

      def find_order_for(session)
        id = session.metadata.respond_to?(:[]) ? session.metadata['order_id'] : nil
        return Order.find_by(id: id) if id.present?

        Order.find_by(stripe_checkout_session_id: session.id)
      end
    end
  end
end
