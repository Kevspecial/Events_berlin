# frozen_string_literal: true

require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:one)
  end

  def build_order(attrs = {})
    Order.new({
      user: @user,
      event: @event,
      total_amount: 59.98,
      expires_at: 15.minutes.from_now
    }.merge(attrs))
  end

  test 'is valid with required attributes' do
    assert build_order.valid?
  end

  test 'defaults to pending and unpaid' do
    order = build_order
    order.save!
    assert_equal 'pending', order.status
    assert_equal 'unpaid', order.payment_status
    assert_equal 'eur', order.currency
  end

  test 'rejects an unknown status' do
    order = build_order(status: 'banana')
    assert_not order.valid?
    assert_includes order.errors[:status], 'is not included in the list'
  end

  test 'rejects a negative total amount' do
    order = build_order(total_amount: -1)
    assert_not order.valid?
  end

  test 'status predicates reflect the status column' do
    assert build_order(status: 'pending').pending?
    assert build_order(status: 'paid').paid?
    assert build_order(status: 'cancelled').cancelled?
    assert build_order(status: 'expired').expired?
    assert build_order(status: 'refunded').refunded?
  end

  test 'free? is true only when total amount is zero' do
    assert build_order(total_amount: 0).free?
    assert_not build_order(total_amount: 0.01).free?
  end

  test 'holding_inventory includes paid orders' do
    order = build_order(status: 'paid')
    order.save!
    assert_includes Order.holding_inventory, order
  end

  test 'holding_inventory includes unexpired pending orders' do
    order = build_order(status: 'pending', expires_at: 5.minutes.from_now)
    order.save!
    assert_includes Order.holding_inventory, order
  end

  test 'holding_inventory excludes expired pending orders' do
    order = build_order(status: 'pending', expires_at: 5.minutes.ago)
    order.save!
    assert_not_includes Order.holding_inventory, order
  end

  test 'holding_inventory excludes cancelled and expired orders' do
    cancelled = build_order(status: 'cancelled')
    cancelled.save!
    expired = build_order(status: 'expired')
    expired.save!

    assert_not_includes Order.holding_inventory, cancelled
    assert_not_includes Order.holding_inventory, expired
  end

  test 'default_expiry is fifteen minutes out' do
    freeze_time do
      assert_in_delta 15.minutes.from_now.to_i, Order.default_expiry.to_i, 1
    end
  end
end
