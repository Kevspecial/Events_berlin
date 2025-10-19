require 'test_helper'

class BookingTest < ActiveSupport::TestCase
  test 'calculates total price on validation' do
    user = users(:one)
    event = events(:one)
    ticket_type = ticket_types(:one)

    booking = Booking.new(
      user: user,
      event: event,
      ticket_type: ticket_type,
      quantity: 2
    )

    booking.valid?
    assert_equal ticket_type.price * 2, booking.total_price
  end

  test 'requires valid status' do
    booking = Booking.new(status: 'invalid_status')
    assert_not booking.valid?
    assert_includes booking.errors[:status], 'is not included in the list'
  end
end
