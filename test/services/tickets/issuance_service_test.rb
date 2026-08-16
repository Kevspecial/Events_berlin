# frozen_string_literal: true

require 'test_helper'

module Tickets
  class IssuanceServiceTest < ActiveSupport::TestCase
    setup do
      @order = Order.create!(
        user: users(:two), event: events(:one),
        status: 'pending', payment_status: 'unpaid',
        total_amount: 0, expires_at: Order.default_expiry
      )
      @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:one), quantity: 3, status: 'confirmed'
      )
      @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:two), quantity: 2, status: 'confirmed'
      )
      @order.update!(
        total_amount: @order.bookings.sum(:total_price),
        status: 'paid', payment_status: 'paid', paid_at: Time.current
      )
    end

    test 'creates one ticket per unit of quantity across every booking' do
      result = Tickets::IssuanceService.new(order: @order).call

      assert result[:success], result[:error]
      assert_equal 5, result[:tickets].size
      assert_equal 5, @order.reload.tickets.count
    end

    test 'gives every ticket a distinct code' do
      result = Tickets::IssuanceService.new(order: @order).call
      codes = result[:tickets].map(&:code)

      assert_equal codes.size, codes.uniq.size
      codes.each { |code| assert_match(/\AEB-[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{12}\z/, code) }
    end

    test 'issues every ticket in the issued state' do
      result = Tickets::IssuanceService.new(order: @order).call
      assert(result[:tickets].all?(&:issued?))
    end

    test 'is idempotent' do
      Tickets::IssuanceService.new(order: @order).call

      assert_no_difference 'Ticket.count' do
        result = Tickets::IssuanceService.new(order: @order).call
        assert result[:success]
        assert_equal 5, result[:tickets].size
      end
    end

    test 'refuses to issue for an unpaid order' do
      @order.update!(status: 'pending', payment_status: 'unpaid', paid_at: nil)
      result = Tickets::IssuanceService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_paid, result[:code]
      assert_equal 0, @order.reload.tickets.count
    end

    test 'retries past a code collision without losing the rest of the order' do
      # The first generated code duplicates an existing ticket. A collision must
      # cost one retry, not the whole order's issuance.
      sequence = [
        tickets(:issued_one).code, # collides — forces one retry
        'EB-Z9Y8X7W6V5T4', 'EB-Y8X7W6V5T4S3', 'EB-X7W6V5T4S3R2',
        'EB-W6V5T4S3R2Q1', 'EB-V5T4S3R2Q1P0'
      ]

      Ticket.stub(:generate_code, -> { sequence.shift }) do
        result = Tickets::IssuanceService.new(order: @order).call
        assert result[:success], result[:error]
      end

      assert_equal 5, @order.reload.tickets.count
      assert_equal 5, @order.tickets.pluck(:code).uniq.size
      assert_empty sequence, 'expected every generated code to be consumed'
    end

    test 'payment completion issues tickets automatically' do
      @order.update!(status: 'pending', payment_status: 'unpaid', paid_at: nil, tickets_issued_at: nil)

      Orders::PaymentCompletionService.new(order: @order, payment_intent_id: 'pi_x').call

      assert_equal 5, @order.reload.tickets.count
    end

    test 'locks the order row before issuing' do
      statements = []
      collector = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }

      ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') do
        Tickets::IssuanceService.new(order: @order).call
      end

      assert(statements.any? { |sql| sql.include?('FOR UPDATE') },
             'expected the order row to be locked before the issuance guard')
    end

    test 'a second issuance sees the first and adds nothing' do
      first = Tickets::IssuanceService.new(order: @order).call
      assert_equal 5, first[:tickets].size

      assert_no_difference 'Ticket.count' do
        second = Tickets::IssuanceService.new(order: @order.reload).call
        assert second[:success]
        assert_equal 5, second[:tickets].size
        assert_equal first[:tickets].map(&:code).sort, second[:tickets].map(&:code).sort
      end
    end

    test 'a code collision does not cost the order its other tickets' do
      sequence = [
        tickets(:issued_one).code,
        'EB-Z9Y8X7W6V5T4', 'EB-Y8X7W6V5T4S3', 'EB-X7W6V5T4S3R2',
        'EB-W6V5T4S3R2Q1', 'EB-V5T4S3R2Q1P0'
      ]

      Ticket.stub(:generate_code, -> { sequence.shift }) do
        Tickets::IssuanceService.new(order: @order).call
      end

      assert_equal 5, @order.reload.tickets.count
      assert_equal 5, @order.tickets.pluck(:code).uniq.size
    end
  end
end
