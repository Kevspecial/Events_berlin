# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.organizer? || user.admin?
  end

  def update?
    user.admin? || record.creator_id == user.id
  end

  def destroy?
    user.admin? || record.creator_id == user.id
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
