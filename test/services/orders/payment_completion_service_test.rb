# frozen_string_literal: true

require 'test_helper'

module Orders
  class PaymentCompletionServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:pending_two)
      @booking = @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:one), quantity: 2, status: 'pending'
      )
    end

    def complete(intent: 'pi_test_abc')
      Orders::PaymentCompletionService.new(order: @order, payment_intent_id: intent).call
    end

    test 'marks the order paid and stamps the timestamp' do
      freeze_time do
        result = complete
        assert result[:success], result[:error]
        @order.reload
        assert_equal 'paid', @order.status
        assert_equal 'paid', @order.payment_status
        assert_equal Time.current.to_i, @order.paid_at.to_i
      end
    end

    test 'records the payment intent id' do
      complete(intent: 'pi_live_xyz')
      assert_equal 'pi_live_xyz', @order.reload.stripe_payment_intent_id
    end

    test 'cascades bookings to confirmed' do
      complete
      assert_equal 'confirmed', @booking.reload.status
    end

    test 'is idempotent when the order is already paid' do
      complete
      first_paid_at = @order.reload.paid_at

      travel 1.hour do
        result = complete
        assert result[:success]
        assert_equal first_paid_at.to_i, @order.reload.paid_at.to_i
      end
    end

    test 'refuses to resurrect a cancelled order' do
      @order.update!(status: 'cancelled')
      result = complete

      assert_not result[:success]
      assert_equal :not_completable, result[:code]
    end

    test 'completes an order whose hold lapsed but whose payment landed' do
      @order.update!(expires_at: 1.minute.ago)
      result = complete

      assert result[:success], result[:error]
      assert_equal 'paid', @order.reload.status
    end

    test 'confirms bookings even when one would fail validation' do
      # Corrupt a booking so a validating update would raise. quantity is used
      # (rather than total_price) because total_price carries a DB-level
      # NOT NULL constraint that update_column cannot get past at all; quantity
      # only carries a model-level numericality validation, which is exactly
      # the kind of failure a validating cascade must not be blocked by. The
      # money has already been captured, so the cascade must still complete.
      @booking.update_column(:quantity, 0) # rubocop:disable Rails/SkipsModelValidations

      result = complete

      assert result[:success], result[:error]
      assert_equal 'paid', @order.reload.status
      assert_equal 'confirmed', @booking.reload.status
    end

    test 'takes a row lock before transitioning' do
      statements = []
      collector = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }

      ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') do
        complete
      end

      assert(statements.any? { |sql| sql.include?('FOR UPDATE') },
             'expected the order row to be locked before the paid check')
    end
  end
end
