# frozen_string_literal: true

class Attending < ApplicationRecord
  belongs_to :attendee, class_name: 'User', inverse_of: :attendings
  belongs_to :attended_event, class_name: 'Event', inverse_of: :attendings
end
