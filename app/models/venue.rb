# frozen_string_literal: true

class Venue < ApplicationRecord
  has_many :events, dependent: :nullify

  validates :name, presence: true
  validates :address, presence: true
  validates :city, presence: true
  validates :capacity, numericality: { greater_than: 0, allow_nil: true }
end
