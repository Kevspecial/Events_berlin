# frozen_string_literal: true

class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :event
  belongs_to :ticket_type
  belongs_to :order
  has_many :tickets, dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending confirmed cancelled] }
  validates :payment_status, inclusion: { in: %w[unpaid paid failed refunded] }, allow_nil: true

  before_validation :calculate_total_price

  scope :confirmed, -> { where(status: 'confirmed') }
  scope :pending, -> { where(status: 'pending') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :paid, -> { where(payment_status: 'paid') }
  # An order-level hold is necessary but not sufficient: a booking cancelled on
  # its own must stop holding stock even while its order is still live.
  scope :holding_inventory, lambda {
    joins(:order).merge(Order.holding_inventory).where.not(status: 'cancelled')
  }

  # Status check methods
  def pending?
    status == 'pending'
  end

  def confirmed?
    status == 'confirmed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def paid?
    payment_status == 'paid'
  end

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id quantity status payment_status total_price updated_at stripe_checkout_session_id]
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
