# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class CheckoutWebhookTest < ActionDispatch::IntegrationTest
      setup do
        @order = orders(:pending_two)
        @order.update!(stripe_checkout_session_id: 'cs_test_hook')
        @order.bookings.create!(
          user: users(:two), event: events(:one),
          ticket_type: ticket_types(:one), quantity: 1, status: 'pending'
        )
      end

      def completed_event(order_id: @order.id)
        Stripe::Event.construct_from(
          type: 'checkout.session.completed',
          data: {
            object: {
              id: 'cs_test_hook',
              object: 'checkout.session',
              payment_intent: 'pi_test_hook',
              metadata: { 'order_id' => order_id.to_s }
            }
          }
        )
      end

      def post_webhook(stripe_event)
        Stripe::Webhook.stub(:construct_event, stripe_event) do
          post '/api/v1/checkout/webhook',
               params: '{}',
               headers: { 'HTTP_STRIPE_SIGNATURE' => 't=1,v1=fake', 'CONTENT_TYPE' => 'application/json' }
        end
      end

      test 'marks the order paid' do
        post_webhook(completed_event)

        assert_response :success
        assert_equal 'paid', @order.reload.status
        assert_equal 'pi_test_hook', @order.stripe_payment_intent_id
      end

      test 'is idempotent across duplicate deliveries' do
        post_webhook(completed_event)
        paid_at = @order.reload.paid_at

        travel 1.hour do
          post_webhook(completed_event)
          assert_response :success
          assert_equal paid_at.to_i, @order.reload.paid_at.to_i
        end
      end

      test 'acknowledges an unknown order without raising' do
        post_webhook(completed_event(order_id: 999_999))
        assert_response :success
      end

      test 'a refund webhook voids the order tickets' do
        order = orders(:paid_one)
        order.update!(stripe_payment_intent_id: 'pi_refund_hook')

        charge_event = Stripe::Event.construct_from(
          type: 'charge.refunded',
          data: { object: { object: 'charge', payment_intent: 'pi_refund_hook' } }
        )
        post_webhook(charge_event)

        assert_response :success
        order.reload
        assert_equal 'refunded', order.status
        assert(order.tickets.all?(&:cancelled?), 'expected every ticket to be voided')
        assert(order.bookings.all? { |b| b.status == 'cancelled' })
      end

      test 'a partial refund does not void the order tickets' do
        order = orders(:paid_one)
        order.update!(stripe_payment_intent_id: 'pi_partial_hook')

        charge_event = Stripe::Event.construct_from(
          type: 'charge.refunded',
          data: { object: { object: 'charge', payment_intent: 'pi_partial_hook',
                            amount: 10_000, amount_refunded: 1_000 } }
        )
        post_webhook(charge_event)

        assert_response :success
        order.reload
        assert_equal 'paid', order.status
        assert(order.tickets.none?(&:cancelled?), 'a partial refund must not void tickets')
      end

      test 'rejects an invalid signature' do
        Stripe::Webhook.stub(:construct_event, ->(*) { raise Stripe::SignatureVerificationError.new('bad', 'sig') }) do
          post '/api/v1/checkout/webhook',
               params: '{}',
               headers: { 'HTTP_STRIPE_SIGNATURE' => 'nonsense', 'CONTENT_TYPE' => 'application/json' }
        end

        assert_response :bad_request
      end
    end
  end
end
