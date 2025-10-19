# frozen_string_literal: true

class TicketTypeSerializer < ActiveModel::Serializer
  attributes :id, :name, :price, :quantity, :description, :available_quantity
end
