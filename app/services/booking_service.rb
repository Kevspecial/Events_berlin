# frozen_string_literal: true

class BookingService
  attr_reader :user, :event, :ticket_type, :quantity

  def initialize(user:, event:, ticket_type:, quantity:)
    @user = user
    @event = event
    @ticket_type = ticket_type
    @quantity = quantity
  end

  def call
    ActiveRecord::Base.transaction do
      validate_availability!
      create_booking
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def validate_availability!
    if ticket_type.available_quantity < quantity
      raise StandardError, 'Insufficient tickets available'
    end

    if event.capacity && event.available_capacity && event.available_capacity < quantity
      raise StandardError, 'Event capacity exceeded'
    end
  end

  def create_booking
    booking = user.bookings.create!(
      event: event,
      ticket_type: ticket_type,
      quantity: quantity,
      status: 'pending'
    )

    # TODO: Integrate with payment service
    # PaymentService.new(booking).process_payment

    { success: true, booking: booking }
  end
end
