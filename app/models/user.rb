# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles enum
  enum :role, { attendee: 0, organizer: 1, admin: 2 }

  # Invites
  has_many :sent_invites, foreign_key: :inviter_id, class_name: 'Invite', dependent: :destroy, inverse_of: :inviter
  has_many :received_invites, foreign_key: :invitee_id, class_name: 'Invite', dependent: :destroy, inverse_of: :invitee

  # Events the user is attending
  has_many :attendings, foreign_key: :attendee_id, class_name: 'Attending', dependent: :destroy, inverse_of: :attendee
  has_many :attended_events, through: :attendings, source: :attended_event

  # associates user_id with creator_id in events table and allows event.creator method
  has_many :events, foreign_key: :creator_id, class_name: 'Event', dependent: :destroy, inverse_of: :creator

  # Events the user has created
  has_many :created_events, foreign_key: 'creator_id', class_name: 'Event', dependent: :destroy, inverse_of: :creator

  # Bookings
  has_many :bookings, dependent: :destroy
  has_many :booked_events, through: :bookings, source: :event

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email id role updated_at]
  end

  # Define searchable associations for Ransack
  def self.ransackable_associations(_auth_object = nil)
    %w[bookings created_events attended_events]
  end
end
