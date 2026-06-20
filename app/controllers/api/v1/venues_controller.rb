# frozen_string_literal: true

module Api
  module V1
    class VenuesController < BaseController
      skip_before_action :authenticate_user!

      def index
        @venues = Venue.all.order(:name)
        render json: @venues
      end
    end
  end
end
