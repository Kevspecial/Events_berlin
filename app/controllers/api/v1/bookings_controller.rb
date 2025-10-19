# frozen_string_literal: true

module Api
  module V1
    class BookingsController < BaseController
      def index
        @bookings = current_user.bookings.includes(:event, :ticket_type)
        render json: @bookings, include: [:event, :ticket_type]
      end

      def show
        @booking = current_user.bookings.find(params[:id])
        render json: @booking, include: [:event, :ticket_type]
      end

      def create
        @booking = current_user.bookings.build(booking_params)
        authorize @booking

        if @booking.save
          # TODO: Trigger background job for confirmation email
          # BookingConfirmationJob.perform_later(@booking.id)
          render json: @booking, status: :created, include: [:event, :ticket_type]
        else
          render json: { errors: @booking.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @booking = current_user.bookings.find(params[:id])
        authorize @booking

        if @booking.update(booking_params)
          render json: @booking, include: [:event, :ticket_type]
        else
          render json: { errors: @booking.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def cancel
        @booking = current_user.bookings.find(params[:id])
        authorize @booking

        if @booking.update(status: 'cancelled')
          render json: @booking
        else
          render json: { errors: @booking.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def booking_params
        params.require(:booking).permit(:event_id, :ticket_type_id, :quantity, :status)
      end
    end
  end
end
