# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      def profile
        render json: current_user
      end

      def events
        @events = current_user.created_events.includes(:category, :venue)
        render json: @events, include: [:category, :venue]
      end

      def bookings
        @bookings = current_user.bookings.includes(:event, :ticket_type)
        render json: @bookings, include: [:event, :ticket_type]
      end
    end
  end
end
