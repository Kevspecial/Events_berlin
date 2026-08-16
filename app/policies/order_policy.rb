# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    owner? || user.admin?
  end

  def create?
    true
  end

  def cancel?
    owner? || user.admin?
  end

  def destroy?
    cancel?
  end

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(user_id: user.id)
    end
  end

  private

  def owner?
    record.user_id == user.id
  end
end
