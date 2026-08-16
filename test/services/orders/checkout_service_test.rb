# frozen_string_literal: true

require 'test_helper'

module Orders
  class CheckoutServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:pending_two)
      @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:one), quantity: 2, status: 'pending'
      )
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
  end
end
