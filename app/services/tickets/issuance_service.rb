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

    def call
      return { success: true, tickets: order.tickets.to_a } if order.tickets_issued_at.present?
      return failure(:not_paid, 'Tickets are only issued for paid orders') unless order.paid?

      { success: true, tickets: issue_all }
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
