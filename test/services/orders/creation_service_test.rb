# frozen_string_literal: true

require 'test_helper'

module Orders
  # rubocop:disable Metrics/ClassLength
  class CreationServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @event = events(:one)
      @ga = ticket_types(:one)   # price 29.99, quantity 100
      @vip = ticket_types(:two)  # price 99.99, quantity 20
    end

    def call(items, user: @user, event: @event)
      Orders::CreationService.new(user: user, event: event, items: items).call
    end

    test 'creates a pending order with one booking per tier' do
      result = call([{ ticket_type_id: @ga.id, quantity: 2 }, { ticket_type_id: @vip.id, quantity: 1 }])

      assert result[:success], result[:error]
      assert_equal 'pending', result[:order].status
      assert_equal 2, result[:order].bookings.count
      assert_equal @event, result[:order].event
    end

    test 'freezes the total amount across all tiers' do
      result = call([{ ticket_type_id: @ga.id, quantity: 2 }, { ticket_type_id: @vip.id, quantity: 1 }])

      expected = (@ga.price * 2) + (@vip.price * 1)
      assert_equal expected, result[:order].total_amount
    end

    test 'sets a fifteen minute hold' do
      freeze_time do
        result = call([{ ticket_type_id: @ga.id, quantity: 1 }])
        assert_in_delta 15.minutes.from_now.to_i, result[:order].expires_at.to_i, 1
      end
    end

    test 'accepts string keys from JSON params' do
      result = call([{ 'ticket_type_id' => @ga.id, 'quantity' => '2' }])
      assert result[:success], result[:error]
      assert_equal 2, result[:order].bookings.first.quantity
    end

    test 'rejects an empty cart' do
      result = call([])
      assert_not result[:success]
      assert_equal :invalid_items, result[:code]
    end

    test 'rejects a tier belonging to another event' do
      other_tier = TicketType.create!(event: events(:two), name: 'Other', price: 5, quantity: 10)
      result = call([{ ticket_type_id: other_tier.id, quantity: 1 }])

      assert_not result[:success]
      assert_equal :invalid_items, result[:code]
    end

    test 'rejects a non-positive quantity' do
      result = call([{ ticket_type_id: @ga.id, quantity: 0 }])
      assert_not result[:success]
      assert_equal :invalid_items, result[:code]
    end

    test 'rejects an order exceeding available stock' do
      @ga.update!(quantity: 3) # bookings(:one) already holds 2, so 1 remains
      result = call([{ ticket_type_id: @ga.id, quantity: 2 }])

      assert_not result[:success]
      assert_equal :sold_out, result[:code]
      assert_match(/General Admission/, result[:error])
    end

    test 'rejects an order exceeding the per-order cap' do
      # events(:one) caps at 10
      result = call([{ ticket_type_id: @ga.id, quantity: 6 }, { ticket_type_id: @vip.id, quantity: 5 }])

      assert_not result[:success]
      assert_equal :cap_exceeded, result[:code]
      assert_match(/10/, result[:error])
    end

    test 'allows an order exactly at the cap' do
      result = call([{ ticket_type_id: @ga.id, quantity: 10 }])
      assert result[:success], result[:error]
    end

    test 'ignores the cap when the event is uncapped' do
      @event.update!(max_tickets_per_order: nil)
      result = call([{ ticket_type_id: @ga.id, quantity: 40 }])
      assert result[:success], result[:error]
    end

    test 'rejects an order for an event that already started' do
      @event.update!(date: 1.hour.ago)
      result = call([{ ticket_type_id: @ga.id, quantity: 1 }])

      assert_not result[:success]
      assert_equal :event_past, result[:code]
    end

    test 'marks a zero-total order paid immediately' do
      free_event = events(:two)
      free_tier = TicketType.create!(event: free_event, name: 'Free', price: 0, quantity: 50)

      result = call([{ ticket_type_id: free_tier.id, quantity: 2 }], event: free_event)

      assert result[:success], result[:error]
      assert_equal 'paid', result[:order].status
      assert_equal 'paid', result[:order].payment_status
      assert_not_nil result[:order].paid_at
    end

    test 'a free order is issued its tickets immediately' do
      free_event = events(:two)
      free_tier = TicketType.create!(event: free_event, name: 'Free', price: 0, quantity: 50)

      result = call([{ ticket_type_id: free_tier.id, quantity: 2 }], event: free_event)

      assert result[:success], result[:error]
      assert_equal 2, result[:order].reload.tickets.count
      assert_not_nil result[:order].tickets_issued_at
    end

    test 'a free order still succeeds when issuing its tickets fails' do
      free_event = events(:two)
      free_tier = TicketType.create!(event: free_event, name: 'Free', price: 0, quantity: 50)

      failing = ->(*) { raise ActiveRecord::StatementInvalid, 'boom' }
      failing_service = ->(*) { Struct.new(:call).new.tap { |s| s.define_singleton_method(:call, &failing) } }

      Tickets::IssuanceService.stub(:new, failing_service) do
        result = call([{ ticket_type_id: free_tier.id, quantity: 1 }], event: free_event)

        assert result[:success], 'the buyer must still receive their order'
        assert_equal 'paid', result[:order].status
      end
    end

    test 'writes nothing when any tier in the cart is unavailable' do
      @vip.update!(quantity: 0)

      assert_no_difference ['Order.count', 'Booking.count'] do
        call([{ ticket_type_id: @ga.id, quantity: 1 }, { ticket_type_id: @vip.id, quantity: 1 }])
      end
    end

    test 'aggregates duplicate tier lines rather than overselling' do
      @ga.update!(quantity: 3) # bookings(:one) already holds 2, so 1 remains

      result = call([
                      { ticket_type_id: @ga.id, quantity: 1 },
                      { ticket_type_id: @ga.id, quantity: 1 }
                    ])

      assert_not result[:success], 'two lines of 1 must not slip past a stock of 1'
      assert_equal :sold_out, result[:code]
    end

    test 'a duplicated tier becomes one booking with the summed quantity' do
      result = call([
                      { ticket_type_id: @ga.id, quantity: 2 },
                      { ticket_type_id: @ga.id, quantity: 3 }
                    ])

      assert result[:success], result[:error]
      assert_equal 1, result[:order].bookings.count
      assert_equal 5, result[:order].bookings.first.quantity
    end

    test 'locks each tier row before reading availability' do
      statements = []
      collector = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }

      ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') do
        call([{ ticket_type_id: @ga.id, quantity: 1 }])
      end

      assert(statements.any? { |sql| sql.include?('FOR UPDATE') },
             'expected the tier row to be locked with SELECT ... FOR UPDATE')
    end
  end
  # rubocop:enable Metrics/ClassLength
end
