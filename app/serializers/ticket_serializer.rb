# frozen_string_literal: true

class TicketSerializer < ActiveModel::Serializer
  attributes :id, :code, :status, :checked_in_at, :ticket_type_name

  def ticket_type_name
    object.ticket_type.name
  end
end
