# frozen_string_literal: true

require 'test_helper'

module Tickets
  class CheckInServiceTest < ActiveSupport::TestCase
    setup do
      @ticket = tickets(:issued_one)
      @organiser = @ticket.event.creator
      @ticket.event.update!(date: 1.hour.from_now)
    end

    def check_in(ticket: @ticket, by: @organiser)
      Tickets::CheckInService.new(ticket: ticket, scanned_by: by).call
    end

    test 'checks in an issued ticket' do
      freeze_time do
        result = check_in

        assert result[:success], result[:error]
        @ticket.reload
        assert @ticket.checked_in?
        assert_equal Time.current.to_i, @ticket.checked_in_at.to_i
      end
    end

    test 'records who scanned it' do
      check_in
      assert_equal @organiser, @ticket.reload.checked_in_by
    end

    test 'refuses a second scan and reports the original' do
      check_in
      first_time = @ticket.reload.checked_in_at

      travel 10.minutes do
        result = check_in

        assert_not result[:success]
        assert_equal :already_checked_in, result[:code]
        assert_equal first_time.to_i, result[:checked_in_at].to_i
        assert_equal first_time.to_i, @ticket.reload.checked_in_at.to_i
      end
    end

    test 'refuses a cancelled ticket' do
      @ticket.update!(status: 'cancelled', cancelled_at: Time.current)
      result = check_in

      assert_not result[:success]
      assert_equal :cancelled, result[:code]
    end

    test 'refuses a scan long before doors open' do
      @ticket.event.update!(date: 5.days.from_now)
      result = check_in

      assert_not result[:success]
      assert_equal :event_not_started, result[:code]
    end

    test 'allows a scan within the doors-open window' do
      @ticket.event.update!(date: 3.hours.from_now)
      assert check_in[:success]
    end

    test 'allows a scan after the event has begun' do
      @ticket.event.update!(date: 2.hours.ago)
      assert check_in[:success]
    end

    test 'locks the ticket row before reading its status' do
      statements = []
      collector = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }

      ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') do
        check_in
      end

      assert(statements.any? { |sql| sql.include?('FOR UPDATE') },
             'expected the ticket row to be locked before the status guards run')
    end
  end
end
