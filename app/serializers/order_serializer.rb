# frozen_string_literal: true

class OrderSerializer < ActiveModel::Serializer
  attributes :id, :reference, :status, :payment_status, :total_amount,
             :currency, :expires_at, :paid_at, :cancelled_at, :refunded_at

  attribute(:cancellable) { object.paid? && object.event.cancellable? }
  attribute(:ticket_count) { object.bookings.sum(:quantity) }

  belongs_to :event
  has_many :bookings
end
