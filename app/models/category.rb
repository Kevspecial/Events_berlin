# frozen_string_literal: true

class Category < ApplicationRecord
  has_many :events, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "description", "id", "name", "updated_at"]
  end

  # Define searchable associations for Ransack
  def self.ransackable_associations(_auth_object = nil)
    ["events"]
  end
end
