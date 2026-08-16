# frozen_string_literal: true

class TicketType < ApplicationRecord
  belongs_to :event
  has_many :bookings, dependent: :restrict_with_error

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  # Inventory is held by bookings whose order is paid, or pending and not yet
  # lapsed. Order.holding_inventory is the single source of truth.
  def available_quantity
    [quantity - bookings.holding_inventory.sum(:quantity), 0].max
  end

  def sold_out?
    available_quantity.zero?
  end

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name price quantity updated_at]
  end

  # Define searchable associations for Ransack
  def self.ransackable_associations(_auth_object = nil)
    %w[bookings event]
  end
end
