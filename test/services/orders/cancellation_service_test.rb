# frozen_string_literal: true

require 'test_helper'

module Orders
  # rubocop:disable Metrics/ClassLength -- a test file with one example per
  # behaviour is long by nature; splitting it would obscure the coverage map.
  class CancellationServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:paid_one)
      @event = @order.event
      @event.update!(date: 30.days.from_now, cancel_cutoff_hours: 24)
    end

    def stub_refund(id: 're_test_123')
      stub_request(:post, 'https://api.stripe.com/v1/refunds')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { id: id, object: 'refund', status: 'succeeded' }.to_json
        )
    end

    def cancel(reason: 'change_of_plans')
      Orders::CancellationService.new(order: @order, reason: reason).call
    end

    test 'cancels a paid order well before the cutoff' do
      stub_refund
      result = cancel

      assert result[:success], result[:error]
      assert_equal 'cancelled', @order.reload.status
      assert_not_nil @order.cancelled_at
    end

    test 'issues a Stripe refund against the payment intent' do
      stub_refund
      cancel

      assert_requested(:post, 'https://api.stripe.com/v1/refunds') do |req|
        req.body.include?('payment_intent=pi_test_paid_one')
      end
    end

    test 'sends a deterministic idempotency key with the refund' do
      stub_refund
      cancel

      assert_requested(:post, 'https://api.stripe.com/v1/refunds') do |req|
        req.headers['Idempotency-Key'] == "order-#{@order.id}-refund"
      end
    end

    test 'records the reason' do
      stub_refund
      cancel(reason: 'illness')

      assert_equal 'illness', @order.reload.refund_reason
    end

    test 'cascades bookings and tickets to cancelled' do
      stub_refund
      cancel

      assert(@order.reload.bookings.all? { |b| b.status == 'cancelled' })
      assert(@order.tickets.all?(&:cancelled?))
      assert(@order.tickets.all? { |t| t.cancelled_at.present? })
    end

    test 'releases the inventory it was holding' do
      stub_refund
      before = ticket_types(:one).available_quantity

      cancel

      assert_equal before + 2, ticket_types(:one).reload.available_quantity
    end

    test 'refuses once inside the cutoff window' do
      @event.update!(date: 2.hours.from_now)
      result = cancel

      assert_not result[:success]
      assert_equal :past_cutoff, result[:code]
      assert_equal 'paid', @order.reload.status
    end

    test 'allows cancellation at any time when the event has no cutoff' do
      @event.update!(date: 1.hour.from_now, cancel_cutoff_hours: nil)
      stub_refund

      assert cancel[:success]
    end

    test 'refuses to cancel when a ticket has already been checked in' do
      @order.tickets.first.update!(status: 'checked_in', checked_in_at: Time.current)

      result = cancel

      assert_not result[:success]
      assert_equal :already_attended, result[:code]
      assert_equal 'paid', @order.reload.status
      assert_not_requested :post, 'https://api.stripe.com/v1/refunds'
    end

    test 'refuses an order that is not paid' do
      @order.update!(status: 'pending', payment_status: 'unpaid')
      result = cancel

      assert_not result[:success]
      assert_equal :not_cancellable, result[:code]
    end

    test 'refuses an already cancelled order' do
      @order.update!(status: 'cancelled')
      result = cancel

      assert_not result[:success]
      assert_equal :not_cancellable, result[:code]
    end

    test 'cancels a free order without calling Stripe' do
      @order.update!(total_amount: 0, stripe_payment_intent_id: nil)
      result = cancel

      assert result[:success], result[:error]
      assert_equal 'cancelled', @order.reload.status
      assert_not_requested :post, 'https://api.stripe.com/v1/refunds'
    end

    test 'leaves the order untouched when the refund fails' do
      stub_request(:post, 'https://api.stripe.com/v1/refunds')
        .to_return(
          status: 400,
          headers: { 'Content-Type' => 'application/json' },
          body: { error: { message: 'charge already refunded', type: 'invalid_request_error' } }.to_json
        )

      result = cancel

      assert_not result[:success]
      assert_equal :refund_failed, result[:code]
      assert_equal 'paid', @order.reload.status
      assert(@order.tickets.none?(&:cancelled?))
    end
  end
  # rubocop:enable Metrics/ClassLength
end
