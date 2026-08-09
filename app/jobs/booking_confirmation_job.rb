# frozen_string_literal: true

class BookingConfirmationJob < ApplicationJob
  queue_as :mailers

  def perform(booking_id)
    booking = Booking.includes(:event, :user).find(booking_id)
    BookingMailer.confirmation(booking).deliver_now
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "BookingConfirmationJob: #{e.message}"
  end
end
