# frozen_string_literal: true

require 'test_helper'

class BookingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:one)
    @ticket_type = ticket_types(:one)
  end

  test 'creates booking successfully when capacity available' do
    result = BookingService.new(
      user: @user,
      event: @event,
      ticket_type: @ticket_type,
      quantity: 1
    ).call

    assert result[:success], "Expected success but got error: #{result[:error]}"
    assert_not_nil result[:booking]
    assert_equal 'pending', result[:booking].status
  end

  test 'fails when ticket type is sold out' do
    @ticket_type.update!(quantity: 0)

    result = BookingService.new(
      user: @user,
      event: @event,
      ticket_type: @ticket_type,
      quantity: 1
    ).call

    assert_not result[:success]
    assert_match(/Insufficient tickets/i, result[:error])
  end

  test 'fails when event capacity is exceeded' do
    # events(:one) already has bookings totalling 3 quantity (fixtures: one=2, two=1)
    @event.update!(capacity: 3)

    result = BookingService.new(
      user: @user,
      event: @event,
      ticket_type: @ticket_type,
      quantity: 1
    ).call

    assert_not result[:success]
    assert_match(/capacity/i, result[:error])
  end

  test 'calculates total price based on ticket type price and quantity' do
    result = BookingService.new(
      user: @user,
      event: @event,
      ticket_type: @ticket_type,
      quantity: 2
    ).call

    assert result[:success]
    expected_price = @ticket_type.price * 2
    assert_equal expected_price, result[:booking].total_price
  end
end
