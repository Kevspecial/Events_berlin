# frozen_string_literal: true

class Order < ApplicationRecord
  STATUSES = %w[pending paid expired cancelled refunded].freeze
  PAYMENT_STATUSES = %w[unpaid paid refunded failed].freeze
  HOLD_DURATION = 15.minutes

  belongs_to :user
  belongs_to :event
  has_many :bookings, dependent: :destroy
  has_many :tickets, through: :bookings

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payment_status, presence: true, inclusion: { in: PAYMENT_STATUSES }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :expires_at, presence: true

  # An order holds inventory while it is paid, or pending and not yet lapsed.
  scope :holding_inventory, lambda {
    where(status: 'paid').or(where(status: 'pending').where(expires_at: Time.current..))
  }
  scope :sweepable, -> { where(status: 'pending').where(expires_at: ...Time.current) }

  def self.default_expiry
    HOLD_DURATION.from_now
  end

  STATUSES.each do |state|
    define_method(:"#{state}?") { status == state }
  end

  def free?
    total_amount.to_d.zero?
  end

  def reference
    format('ORD-%06d', id)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at expires_at id paid_at payment_status status total_amount updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[bookings event tickets user]
  end
end
