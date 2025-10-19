# frozen_string_literal: true

class EventSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :location, :date, :private, :price, :capacity, :available_capacity, :created_at, :updated_at

  belongs_to :creator
  belongs_to :category
  belongs_to :venue
  has_many :ticket_types
end
