# frozen_string_literal: true

require 'test_helper'

module Orders
  class CheckoutServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:pending_two)
      # The fixture booking's frozen total_price (99.99, i.e. 9999 cents) is a
      # numeric prefix of the live price the frozen-price regression test
      # below writes onto its ticket type (999.99, i.e. 99999 cents). Left
      # alone, a substring check on the request body would match either
      # value and the test would pass even against the pre-fix bug, so give
      # the fixture booking a frozen price that can't collide that way.
      @order.bookings.first.update_column(:total_price, 45.00) # rubocop:disable Rails/SkipsModelValidations
      @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:one), quantity: 2, status: 'pending'
      )
      # The fixture's total_amount only accounts for the fixture booking;
      # bring it in line with the bookings above so the reconciliation guard
      # in CheckoutService does not fire in tests that expect success.
      @order.update!(total_amount: @order.bookings.reload.sum(:total_price))
    end

    def stub_session(id: 'cs_test_123', url: 'https://checkout.stripe.com/c/pay/cs_test_123')
      stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { id: id, url: url, object: 'checkout.session' }.to_json
        )
    end

    test 'returns the checkout url and persists the session id' do
      stub_session
      result = Orders::CheckoutService.new(order: @order).call

      assert result[:success], result[:error]
      assert_equal 'https://checkout.stripe.com/c/pay/cs_test_123', result[:checkout_url]
      assert_equal 'cs_test_123', @order.reload.stripe_checkout_session_id
    end

    test 'sends one line item per booking' do
      stub_session
      Orders::CheckoutService.new(order: @order).call

      assert_requested(:post, 'https://api.stripe.com/v1/checkout/sessions') do |req|
        req.body.include?('line_items[0]') && req.body.include?('line_items[1]')
      end
    end

    test 'refuses an order that is already paid' do
      @order.update!(status: 'paid')
      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_payable, result[:code]
    end

    test 'refuses an order whose hold has lapsed' do
      @order.update!(expires_at: 1.minute.ago)
      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_payable, result[:code]
    end

    test 'refuses a free order' do
      @order.update!(total_amount: 0)
      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_payable, result[:code]
    end

    test 'surfaces a Stripe failure without changing the order' do
      stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
        .to_return(
          status: 402,
          headers: { 'Content-Type' => 'application/json' },
          body: { error: { message: 'Your card was declined', type: 'card_error' } }.to_json
        )

      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :stripe_error, result[:code]
      assert_nil @order.reload.stripe_checkout_session_id
    end

    test 'reuses an open session instead of creating a second one' do
      stub_session
      first = Orders::CheckoutService.new(order: @order).call
      assert first[:success], first[:error]

      stub_request(:get, %r{https://api\.stripe\.com/v1/checkout/sessions/cs_test_123})
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { id: 'cs_test_123', object: 'checkout.session', status: 'open',
                  url: 'https://checkout.stripe.com/c/pay/cs_test_123' }.to_json
        )

      second = Orders::CheckoutService.new(order: @order.reload).call

      assert second[:success], second[:error]
      assert_equal first[:session_id], second[:session_id]
      assert_requested :post, 'https://api.stripe.com/v1/checkout/sessions', times: 1
    end

    test 'charges the price frozen at order creation, not the current tier price' do
      original_unit_cents = (@order.bookings.first.total_price / @order.bookings.first.quantity * 100).round
      @order.bookings.first.ticket_type.update!(price: 999.99)

      stub_session
      result = Orders::CheckoutService.new(order: @order).call

      assert result[:success], result[:error]
      assert_requested(:post, 'https://api.stripe.com/v1/checkout/sessions') do |req|
        req.body.include?("unit_amount%5D=#{original_unit_cents}") ||
          req.body.include?("unit_amount]=#{original_unit_cents}")
      end
    end

    test 'refuses to charge when line items disagree with the order total' do
      @order.update!(total_amount: @order.total_amount + 50)

      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :amount_mismatch, result[:code]
      assert_not_requested :post, 'https://api.stripe.com/v1/checkout/sessions'
    end
  end
end
