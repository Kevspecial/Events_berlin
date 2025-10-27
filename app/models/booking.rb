# frozen_string_literal: true

class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :event
  belongs_to :ticket_type

  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending confirmed cancelled] }

  before_validation :calculate_total_price, if: :quantity_changed?

  scope :confirmed, -> { where(status: 'confirmed') }
  scope :pending, -> { where(status: 'pending') }
  scope :cancelled, -> { where(status: 'cancelled') }

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id quantity status total_price updated_at]
  end

  # Define searchable associations for Ransack
  def self.ransackable_associations(_auth_object = nil)
    %w[event ticket_type user]
  end

  private

  def calculate_total_price
    self.total_price = quantity * ticket_type.price if ticket_type && quantity
  end
end
