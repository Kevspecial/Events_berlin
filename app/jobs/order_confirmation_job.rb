# frozen_string_literal: true

class OrderConfirmationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return if order.nil? || order.tickets.empty?

    OrderMailer.confirmation(order).deliver_now
  end
end
