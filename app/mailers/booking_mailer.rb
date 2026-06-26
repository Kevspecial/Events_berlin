# frozen_string_literal: true

class BookingMailer < ApplicationMailer
  def confirmation(booking)
    @booking = booking
    @event = booking.event
    @user = booking.user

    mail(to: @user.email, subject: "Booking Confirmed: #{@event.name}")
  end
end
