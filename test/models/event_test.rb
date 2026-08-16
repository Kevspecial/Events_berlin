# frozen_string_literal: true

require 'test_helper'

class EventTest < ActiveSupport::TestCase
  setup { @event = events(:one) }

  test 'defaults the cancel cutoff to 24 hours' do
    assert_equal 24, @event.cancel_cutoff_hours
  end

  test 'defaults the ticket cap to 10' do
    assert_equal 10, @event.ticket_cap
  end

  test 'cancellable_until is the cutoff before the event date' do
    @event.update!(cancel_cutoff_hours: 48)
    assert_equal @event.date - 48.hours, @event.cancellable_until
  end

  test 'cancellable_until is nil when no cutoff is configured' do
    @event.update!(cancel_cutoff_hours: nil)
    assert_nil @event.cancellable_until
  end

  test 'cancellable? is true well before the cutoff' do
    assert @event.cancellable?(@event.date - 72.hours)
  end

  test 'cancellable? is false inside the cutoff window' do
    assert_not @event.cancellable?(@event.date - 1.hour)
  end

  test 'cancellable? is false after the event has started' do
    assert_not @event.cancellable?(@event.date + 1.hour)
  end

  test 'cancellable? requires no advance notice, but not after the event has started' do
    @event.update!(cancel_cutoff_hours: nil)
    assert @event.cancellable?(@event.date - 1.minute)
    assert_not @event.cancellable?(@event.date + 1.hour)
  end

  test 'ticket_cap returns nil when uncapped' do
    @event.update!(max_tickets_per_order: nil)
    assert_nil @event.ticket_cap
  end

  test 'rejects a negative cutoff' do
    @event.cancel_cutoff_hours = -1
    assert_not @event.valid?
  end

  test 'rejects a zero ticket cap' do
    @event.max_tickets_per_order = 0
    assert_not @event.valid?
  end
end
