# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!
      # API endpoints typically use token-based authentication (e.g., JWT)
      # For session-based authentication, consider using CSRF tokens
      # or implementing proper token-based auth instead of skipping CSRF protection
      protect_from_forgery with: :null_session

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from Pundit::NotAuthorizedError, with: :forbidden

      private

      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.message }, status: :unprocessable_entity
      end

      def forbidden
        render json: { error: 'You are not authorized to perform this action' }, status: :forbidden
      end
    end
  end
end
