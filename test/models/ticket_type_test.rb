# frozen_string_literal: true

require 'test_helper'

class TicketTypeTest < ActiveSupport::TestCase
  setup { @ticket_type = ticket_types(:one) }

  test 'available_quantity subtracts bookings on paid orders' do
    # ticket_types(:one) has quantity 100; bookings(:one) holds 2 on a paid order.
    assert_equal 98, @ticket_type.available_quantity
  end

  test 'available_quantity subtracts unexpired pending orders' do
    Booking.create!(
      order: orders(:pending_two), user: users(:two), event: events(:one),
      ticket_type: @ticket_type, quantity: 5, status: 'pending'
    )
    assert_equal 93, @ticket_type.available_quantity
  end

  test 'available_quantity ignores bookings whose order lapsed' do
    Booking.create!(
      order: orders(:pending_two), user: users(:two), event: events(:one),
      ticket_type: @ticket_type, quantity: 5, status: 'pending'
    )
    orders(:pending_two).update!(expires_at: 1.minute.ago)

    assert_equal 98, @ticket_type.available_quantity
  end

  test 'available_quantity ignores cancelled orders' do
    orders(:paid_one).update!(status: 'cancelled')
    assert_equal 100, @ticket_type.available_quantity
  end

  test 'sold_out? is true when nothing remains' do
    @ticket_type.update!(quantity: 2)
    assert @ticket_type.sold_out?
  end

  test 'sold_out? is false while stock remains' do
    assert_not @ticket_type.sold_out?
  end

  test 'available_quantity never reports a negative number' do
    @ticket_type.update!(quantity: 1)
    assert_equal 0, @ticket_type.available_quantity
  end

  test 'event available_capacity follows the same holding rules' do
    event = events(:one)
    # bookings(:one) holds 2 on a paid order, bookings(:two) holds 1 on a
    # pending order that has not lapsed. Capacity is 500.
    assert_equal 497, event.available_capacity

    orders(:pending_two).update!(expires_at: 1.minute.ago)
    assert_equal 498, event.reload.available_capacity
  end

  test 'available_quantity releases stock from a booking cancelled on its own' do
    # bookings(:one) holds 2 against a paid order. Cancelling just that booking,
    # leaving the order paid, must return its stock to the pool.
    assert_equal 98, @ticket_type.available_quantity

    bookings(:one).update!(status: 'cancelled')

    assert_equal 100, @ticket_type.reload.available_quantity
    assert_equal 'paid', orders(:paid_one).reload.status
  end
end
