# frozen_string_literal: true

class BookingConfirmationJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    Booking.find(booking_id)

    # TODO: Send confirmation email
    # BookingMailer.confirmation_email(booking).deliver_now

    Rails.logger.info "Booking confirmation job completed for booking ##{booking_id}"
  end
end
