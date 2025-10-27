# frozen_string_literal: true

class VenueSerializer < ActiveModel::Serializer
  attributes :id, :name, :address, :city, :capacity
end
