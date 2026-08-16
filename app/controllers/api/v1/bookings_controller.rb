# frozen_string_literal: true

module Api
  module V1
    class BookingsController < BaseController
      def index
        @bookings = current_user.bookings.includes(:event, :ticket_type)
        render json: @bookings, include: %i[event ticket_type]
      end

      def show
        @booking = current_user.bookings.find(params[:id])
        render json: @booking, include: %i[event ticket_type]
      end
    end
  end
end
