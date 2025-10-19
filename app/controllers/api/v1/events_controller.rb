# frozen_string_literal: true

module Api
  module V1
    class EventsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show]

      def index
        @events = Event.all
                       .by_category(params[:category_id])
                       .by_location(params[:location])
                       .by_date_range(params[:start_date], params[:end_date])
                       .search_by_name(params[:search])

        @events = params[:upcoming] == 'true' ? @events.upcoming : @events

        render json: @events, include: [:category, :venue, :creator]
      end

      def show
        @event = Event.includes(:category, :venue, :creator, :ticket_types).find(params[:id])
        render json: @event, include: [:category, :venue, :creator, :ticket_types]
      end

      def create
        @event = current_user.created_events.build(event_params)
        authorize @event

        if @event.save
          render json: @event, status: :created
        else
          render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @event = Event.find(params[:id])
        authorize @event

        if @event.update(event_params)
          render json: @event
        else
          render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @event = Event.find(params[:id])
        authorize @event

        @event.destroy
        head :no_content
      end

      private

      def event_params
        params.require(:event).permit(
          :name, :description, :location, :date, :private,
          :category_id, :venue_id, :price, :capacity
        )
      end
    end
  end
end
