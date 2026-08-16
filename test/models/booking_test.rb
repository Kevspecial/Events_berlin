# frozen_string_literal: true

require 'test_helper'

class BookingTest < ActiveSupport::TestCase
  test 'belongs to an order' do
    assert_equal orders(:paid_one), bookings(:one).order
  end

  test 'requires an order' do
    booking = Booking.new(
      user: users(:one), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 1, status: 'pending'
    )
    assert_not booking.valid?
    assert_includes booking.errors[:order], 'must exist'
  end

  test 'holding_inventory includes bookings on paid orders' do
    assert_includes Booking.holding_inventory, bookings(:one)
  end

  test 'holding_inventory excludes bookings whose order lapsed' do
    orders(:pending_two).update!(expires_at: 5.minutes.ago)
    assert_not_includes Booking.holding_inventory, bookings(:two)
  end

  test 'calculates total price from ticket type and quantity' do
    booking = Booking.create!(
      order: orders(:paid_one), user: users(:one), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 3, status: 'pending'
    )
    assert_equal ticket_types(:one).price * 3, booking.total_price
  end
end
