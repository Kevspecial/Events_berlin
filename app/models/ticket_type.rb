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
end
