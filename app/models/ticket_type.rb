# frozen_string_literal: true

class TicketType < ApplicationRecord
  belongs_to :event
  has_many :bookings, dependent: :restrict_with_error

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  def available_quantity
    quantity - bookings.where(status: %w[confirmed pending]).sum(:quantity)
  end

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "id", "name", "price", "quantity", "updated_at"]
  end

  # Define searchable associations for Ransack
  def self.ransackable_associations(_auth_object = nil)
    ["bookings", "event"]
  end
end
