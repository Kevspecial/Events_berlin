# frozen_string_literal: true

module Tickets
  # Expands a paid order's bookings into individual scanable tickets: a booking
  # for 3 General Admission becomes 3 Ticket rows, each with its own code.
  #
  # Stripe can deliver the same webhook twice, so this is idempotent on
  # orders.tickets_issued_at rather than on a count comparison.
  class IssuanceService
    attr_reader :order

    def initialize(order:)
      @order = order
    end

    # The order row is locked for the whole guard-and-issue sequence, not just
    # the inserts: with_lock already reloads the row under SELECT ... FOR
    # UPDATE, so checking tickets_issued_at and paid? against that same
    # locked read costs nothing extra and closes the race where a second
    # caller (e.g. a retried webhook) passes both guards before the first
    # caller's inserts are visible. A second caller blocks on the lock and,
    # on acquiring it, observes tickets_issued_at already set.
    def call
      order.with_lock do
        next { success: true, tickets: order.tickets.to_a } if order.tickets_issued_at.present?
        next failure(:not_paid, 'Tickets are only issued for paid orders') unless order.paid?

        { success: true, tickets: issue_all }
      end
    end

    private

    def issue_all
      ActiveRecord::Base.transaction do
        created = order.bookings.flat_map { |booking| issue_for(booking) }
        order.update!(tickets_issued_at: Time.current)
        created
      end
    end

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    # Ticket.generate_code checks for a collision before inserting, but that
    # check and the insert are not atomic. A collision is astronomically
    # unlikely (60 bits of entropy) yet its blast radius is not: a raised
    # RecordNotUnique inside the issuance transaction would poison it and roll
    # back every ticket in the order, not just the colliding one. The savepoint
    # confines a retry to the single row.
    def issue_for(booking)
      Array.new(booking.quantity) { create_ticket(booking) }
    end

    def create_ticket(booking, attempts: 3)
      ActiveRecord::Base.transaction(requires_new: true) do
        booking.tickets.create!
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      raise unless code_collision?(e)

      attempts -= 1
      raise if attempts.zero?

      retry
    end

    # A duplicate code surfaces two ways: the model validation catches the
    # common case, and RecordNotUnique catches the genuine race where two
    # processes clear the check at the same instant. Any other validation
    # failure must propagate rather than being retried into oblivion.
    def code_collision?(error)
      return true if error.is_a?(ActiveRecord::RecordNotUnique)

      error.record.errors.of_kind?(:code, :taken)
    end
  end
end
