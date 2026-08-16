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
          handle_checkout_completed(event.data.object)
        when 'payment_intent.succeeded'
          handle_payment_succeeded(event.data.object)
        when 'payment_intent.payment_failed'
          handle_payment_failed(event.data.object)
        else
          Rails.logger.info "Unhandled Stripe event type: #{event.type}"
        end
      end

      def handle_checkout_completed(session)
        booking = Booking.find_by(stripe_checkout_session_id: session.id)
        return unless booking

        booking.update!(
          status: 'confirmed',
          payment_status: 'paid',
          stripe_payment_intent_id: session.payment_intent,
          paid_at: Time.current
        )

        # Trigger confirmation email
        BookingConfirmationJob.perform_later(booking.id)
      end

      def handle_payment_succeeded(payment_intent)
        booking = Booking.find_by(stripe_payment_intent_id: payment_intent.id)
        return unless booking

        booking.update!(
          payment_status: 'paid',
          paid_at: Time.current
        )
      end

      def handle_payment_failed(payment_intent)
        booking = Booking.find_by(stripe_payment_intent_id: payment_intent.id)
        return unless booking

        booking.update!(payment_status: 'failed')
      end
    end
  end
end
