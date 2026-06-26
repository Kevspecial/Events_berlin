# frozen_string_literal: true

require 'test_helper'

class BookingMailerTest < ActionMailer::TestCase
  test 'confirmation email has correct subject and recipient' do
    booking = bookings(:one)
    mail = BookingMailer.confirmation(booking)
    assert_equal "Booking Confirmed: #{booking.event.name}", mail.subject
    assert_equal [booking.user.email], mail.to
    assert_match booking.event.name, mail.body.encoded
  end
end
