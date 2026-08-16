# frozen_string_literal: true

class Ticket < ApplicationRecord
  STATUSES = %w[issued checked_in cancelled].freeze

  # Crockford base32 — no I, L, O, or U, so a code read aloud or typed by
  # hand cannot be confused between 1/I, 0/O, or similar.
  CODE_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
  CODE_LENGTH = 12
  CODE_PREFIX = 'EB-'

  belongs_to :booking
  belongs_to :checked_in_by, class_name: 'User', optional: true
  has_one :order, through: :booking
  has_one :event, through: :booking
  has_one :ticket_type, through: :booking
  has_one :holder, through: :booking, source: :user

  before_validation :assign_code, on: :create

  validates :code, presence: true, uniqueness: true,
                   format: { with: /\A#{CODE_PREFIX}[#{CODE_ALPHABET}]{#{CODE_LENGTH}}\z/o }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :issued, -> { where(status: 'issued') }
  scope :checked_in, -> { where(status: 'checked_in') }
  scope :cancelled, -> { where(status: 'cancelled') }

  STATUSES.each do |state|
    define_method(:"#{state}?") { status == state }
  end

  # The unique index is the real guarantee; this loop only avoids the
  # retry storm a blind insert would cause.
  def self.generate_code
    loop do
      body = Array.new(CODE_LENGTH) { CODE_ALPHABET[SecureRandom.random_number(CODE_ALPHABET.size)] }.join
      candidate = "#{CODE_PREFIX}#{body}"
      return candidate unless exists?(code: candidate)
    end
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[checked_in_at code created_at id status updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[booking event holder ticket_type]
  end

  private

  def assign_code
    self.code ||= self.class.generate_code
  end
end
