# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < ApplicationController
      # Skip authentication for registration
      protect_from_forgery with: :null_session

      def create
        @user = User.new(registration_params)
        @user.role = :attendee # Always create as attendee from frontend

        if @user.save
          render json: {
            id: @user.id,
            email: @user.email,
            role: @user.role,
            created_at: @user.created_at
          }, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def registration_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end
    end
  end
end
