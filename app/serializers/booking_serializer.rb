# frozen_string_literal: true

class BookingSerializer < ActiveModel::Serializer
  attributes :id, :quantity, :total_price, :status, :created_at

  belongs_to :ticket_type
  has_many :tickets
end
