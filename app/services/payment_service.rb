# frozen_string_literal: true

# Service for processing Stripe payments
class PaymentService
  attr_reader :booking

  def initialize(booking)
    @booking = booking
  end

  # Create a payment intent for the booking
  def create_payment_intent
    Stripe::PaymentIntent.create(
      amount: (booking.total_price * 100).to_i, # Amount in cents
      currency: 'eur',
      metadata: {
        booking_id: booking.id,
        event_id: booking.event.id,
        user_id: booking.user.id
      },
      description: "Booking ##{booking.id} for #{booking.event.name}"
    )
  rescue Stripe::StripeError => e
    { success: false, error: e.message }
  end

  # Process a refund for a paid booking
  def process_refund
    return { success: false, error: 'Booking has no payment intent' } if booking.stripe_payment_intent_id.blank?
    return { success: false, error: 'Booking is not paid' } unless booking.paid?

    refund = Stripe::Refund.create(payment_intent: booking.stripe_payment_intent_id)
    booking.update!(payment_status: 'refunded')
    { success: true, refund: refund }
  rescue Stripe::StripeError => e
    { success: false, error: e.message }
  end

  # Retrieve checkout session details
  def self.retrieve_checkout_session(session_id)
    Stripe::Checkout::Session.retrieve(session_id, expand: %w[payment_intent line_items])
  rescue Stripe::StripeError => e
    { error: e.message }
  end
end
