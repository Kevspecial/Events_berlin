# frozen_string_literal: true

require 'test_helper'

module Orders
  # rubocop:disable Metrics/ClassLength -- a test file with one example per
  # behaviour is long by nature; splitting it would obscure the coverage map.
  class CheckoutServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:pending_two)
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
        parsed = Rack::Utils.parse_nested_query(req.body)
        parsed['line_items']['0']['price_data']['unit_amount'] == original_unit_cents.to_s
      end
    end

    test 'refuses to charge when line items disagree with the order total' do
      @order.update!(total_amount: @order.total_amount + 50)

      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :amount_mismatch, result[:code]
      assert_not_requested :post, 'https://api.stripe.com/v1/checkout/sessions'
    end

    test 'refuses a fresh session when the existing one is already complete' do
      stub_session
      Orders::CheckoutService.new(order: @order).call

      stub_request(:get, %r{https://api\.stripe\.com/v1/checkout/sessions/cs_test_123})
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { id: 'cs_test_123', object: 'checkout.session', status: 'complete',
                  url: 'https://checkout.stripe.com/c/pay/cs_test_123' }.to_json
        )
      WebMock.reset_executed_requests!

      result = Orders::CheckoutService.new(order: @order.reload).call

      assert_not result[:success]
      assert_equal :payment_in_progress, result[:code]
      assert_not_requested :post, 'https://api.stripe.com/v1/checkout/sessions'
    end

    test 'creates a fresh session when the existing one expired' do
      stub_session
      Orders::CheckoutService.new(order: @order).call

      stub_request(:get, %r{https://api\.stripe\.com/v1/checkout/sessions/cs_test_123})
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { id: 'cs_test_123', object: 'checkout.session', status: 'expired' }.to_json
        )

      result = Orders::CheckoutService.new(order: @order.reload).call

      assert result[:success], result[:error]
    end

    test 'tolerates a one-cent rounding gap between line items and the order total' do
      @order.update_column(:total_amount, @order.total_amount + 0.01) # rubocop:disable Rails/SkipsModelValidations

      stub_session
      result = Orders::CheckoutService.new(order: @order).call

      assert result[:success], result[:error]
    end

    test 'tolerates rounding drift proportional to the number of units' do
      # A booking of 4 units can drift up to 2 cents through per-unit rounding
      # alone; a flat per-line-item tolerance would wrongly refuse this order.
      booking = @order.bookings.first
      booking.update_column(:quantity, 4) # rubocop:disable Rails/SkipsModelValidations
      @order.update_column(:total_amount, @order.bookings.sum(:total_price) + 0.03) # rubocop:disable Rails/SkipsModelValidations

      stub_session
      result = Orders::CheckoutService.new(order: @order.reload).call

      assert result[:success], result[:error]
    end

    test 'locks the order row before creating a session' do
      statements = []
      collector = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }

      stub_session
      ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') do
        Orders::CheckoutService.new(order: @order).call
      end

      assert(statements.any? { |sql| sql.include?('FOR UPDATE') },
             'expected the order row to be locked across the Stripe call')
    end

    test 'still refuses drift beyond the per-unit tolerance' do
      @order.update_column(:total_amount, @order.total_amount + 25) # rubocop:disable Rails/SkipsModelValidations

      result = Orders::CheckoutService.new(order: @order.reload).call

      assert_not result[:success]
      assert_equal :amount_mismatch, result[:code]
      assert_not_requested :post, 'https://api.stripe.com/v1/checkout/sessions'
    end
  end
  # rubocop:enable Metrics/ClassLength
end
