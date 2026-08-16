# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  def show?
    holder? || organiser? || user.admin?
  end

  def download?
    holder? || user.admin?
  end

  # Scanning is the organiser's job, not the attendee's — a holder must never
  # be able to check in their own ticket.
  def check_in?
    organiser? || user.admin?
  end

  def validate?
    check_in?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.joins(:booking).where(bookings: { user_id: user.id })
    end
  end

  private

  def holder?
    record.booking.user_id == user.id
  end

  def organiser?
    record.event.creator_id == user.id
  end
end
