# frozen_string_literal: true

class BookingPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user.admin? || record.user_id == user.id
  end

  def destroy?
    user.admin?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
