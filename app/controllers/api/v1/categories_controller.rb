# frozen_string_literal: true

module Api
  module V1
    class CategoriesController < BaseController
      skip_before_action :authenticate_user!

      def index
        @categories = Category.all.order(:name)
        render json: @categories
      end
    end
  end
end
