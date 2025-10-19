# frozen_string_literal: true

class BookingSerializer < ActiveModel::Serializer
  attributes :id, :quantity, :total_price, :status, :created_at, :updated_at

  belongs_to :user
  belongs_to :event
  belongs_to :ticket_type
end
