# frozen_string_literal: true

class Event < ApplicationRecord
  belongs_to :creator, class_name: 'User'
  belongs_to :category, optional: true
  belongs_to :venue, optional: true

  # Active Storage attachment for event image
  has_one_attached :image

  # Associations for attendees
  has_many :attendings, foreign_key: :attended_event_id, dependent: :destroy, inverse_of: :attended_event
  has_many :attendees, through: :attendings, source: :attendee

  # Associations for invites
  has_many :invites, dependent: :destroy
  has_many :invitees, through: :invites, source: :invitee

  # Associations for bookings and tickets
  has_many :bookings, dependent: :destroy
  has_many :ticket_types, dependent: :destroy
  has_many :ticket_buyers, through: :bookings, source: :user
  has_many :orders, dependent: :destroy

  validates :name, presence: true
  validates :location, presence: true
  validates :date, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :capacity, numericality: { greater_than: 0, only_integer: true, allow_nil: true }
  validates :cancel_cutoff_hours,
            numericality: { greater_than_or_equal_to: 0, only_integer: true, allow_nil: true }
  validates :max_tickets_per_order,
            numericality: { greater_than: 0, only_integer: true, allow_nil: true }

  # Scopes for filtering
  scope :upcoming, -> { where(date: Time.current..).order(date: :asc) }
  scope :past, -> { where(date: ...Time.current).order(date: :desc) }
  scope :by_category, ->(category_id) { where(category_id: category_id) if category_id.present? }
  scope :by_location, ->(location) { where('location ILIKE ?', "%#{location}%") if location.present? }
  scope :by_date_range, lambda { |start_date, end_date|
    where(date: start_date..end_date) if start_date.present? && end_date.present?
  }
  scope :search_by_name, ->(query) { where('name ILIKE ?', "%#{query}%") if query.present? }

  def available_capacity
    return nil unless capacity

    [capacity - bookings.holding_inventory.sum(:quantity), 0].max
  end

  # The instant after which cancellation is refused. Nil means cancellation
  # is always permitted.
  def cancellable_until
    return nil if cancel_cutoff_hours.nil?

    date - cancel_cutoff_hours.hours
  end

  # A nil cancel_cutoff_hours means "no advance notice required", not
  # "cancellable forever" — an event that has already started is never
  # cancellable, regardless of cutoff configuration.
  def cancellable?(now = Time.current)
    return false if date.present? && now >= date

    deadline = cancellable_until
    return true if deadline.nil?

    now < deadline
  end

  def ticket_cap
    max_tickets_per_order
  end

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    %w[cancel_cutoff_hours capacity created_at date description id location
       max_tickets_per_order name price private updated_at]
  end

  # Define searchable associations for Ransack
  def self.ransackable_associations(_auth_object = nil)
    %w[bookings category creator venue attendees]
  end
end
