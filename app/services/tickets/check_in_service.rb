# frozen_string_literal: true

module Tickets
  # Consumes a ticket at the door. The row is locked for the duration so two
  # simultaneous scans of the same code cannot both succeed — exactly one wins
  # and the other is told when the ticket was already used.
  class CheckInService
    # Doors open this far ahead of the advertised start time.
    DOORS_OPEN_BEFORE = 4.hours

    attr_reader :ticket, :scanned_by

    def initialize(ticket:, scanned_by:)
      @ticket = ticket
      @scanned_by = scanned_by
    end

    def call
      result = ticket.with_lock { attempt_check_in }
      result[:success] ? result.merge(ticket: ticket.reload) : result
    end

    private

    def attempt_check_in
      blocker = blocking_result
      return blocker if blocker

      ticket.update!(status: 'checked_in', checked_in_at: Time.current, checked_in_by: scanned_by)
      { success: true }
    end

    def blocking_result
      return failure(:cancelled, 'This ticket has been cancelled') if ticket.cancelled?
      return already_checked_in_result if ticket.checked_in?
      return failure(:event_not_started, "Doors open at #{doors_open_at.strftime('%H:%M on %-d %B')}") unless open?

      nil
    end

    def already_checked_in_result
      failure(:already_checked_in, 'This ticket was already used')
        .merge(checked_in_at: ticket.checked_in_at, checked_in_by: ticket.checked_in_by&.email)
    end

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def doors_open_at
      ticket.event.date - DOORS_OPEN_BEFORE
    end

    def open?
      Time.current >= doors_open_at
    end
  end
end
