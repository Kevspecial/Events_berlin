# frozen_string_literal: true

require 'test_helper'

class OrderExpiryJobTest < ActiveJob::TestCase
  test 'expires a pending order whose hold lapsed' do
    order = orders(:pending_two)
    order.update!(expires_at: 1.minute.ago)

    OrderExpiryJob.perform_now

    assert_equal 'expired', order.reload.status
  end

  test 'leaves an unexpired pending order alone' do
    order = orders(:pending_two)
    order.update!(expires_at: 5.minutes.from_now)

    OrderExpiryJob.perform_now

    assert_equal 'pending', order.reload.status
  end

  test 'never touches a paid order' do
    order = orders(:paid_one)
    order.update!(expires_at: 1.hour.ago)

    OrderExpiryJob.perform_now

    assert_equal 'paid', order.reload.status
  end

  test 'a swept order leaves its inventory released' do
    order = orders(:pending_two)
    baseline = ticket_types(:one).available_quantity

    order.bookings.create!(
      user: users(:two), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 5, status: 'pending'
    )
    assert_equal baseline - 5, ticket_types(:one).reload.available_quantity,
                 'a live pending order should hold its stock'

    order.update!(expires_at: 1.minute.ago)
    OrderExpiryJob.perform_now

    assert_equal baseline, ticket_types(:one).reload.available_quantity
    assert_equal 'expired', order.reload.status
  end

  test 'cascades bookings to cancelled' do
    order = orders(:pending_two)
    booking = order.bookings.create!(
      user: users(:two), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 1, status: 'pending'
    )
    order.update!(expires_at: 1.minute.ago)

    OrderExpiryJob.perform_now

    assert_equal 'cancelled', booking.reload.status
  end

  test 'returns the number of orders it expired' do
    orders(:pending_two).update!(expires_at: 1.minute.ago)
    assert_equal 1, OrderExpiryJob.perform_now
  end

  test 'warns when a checkout session was started but never completed' do
    order = orders(:pending_two)
    order.update!(expires_at: 1.minute.ago, stripe_checkout_session_id: 'cs_abandoned')

    messages = []
    Rails.logger.stub(:warn, ->(msg) { messages << msg }) do
      OrderExpiryJob.perform_now
    end

    assert(messages.any? { |m| m.include?('cs_abandoned') },
           'expected a warning naming the abandoned checkout session')
  end
end
