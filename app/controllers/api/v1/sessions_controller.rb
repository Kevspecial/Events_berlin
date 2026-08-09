# frozen_string_literal: true

module Api
  module V1
    class SessionsController < ApplicationController
      # Skip authentication for login
      protect_from_forgery with: :null_session

      def create
        @user = User.find_by(email: params[:email]&.downcase)

        if @user&.valid_password?(params[:password])
          token = Warden::JWTAuth::UserEncoder.new.call(@user, :user, nil).first
          sign_in(@user)
          render json: {
            token: token,
            user: {
              id: @user.id,
              email: @user.email,
              role: @user.role,
              created_at: @user.created_at
            }
          }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      def destroy
        sign_out(current_user) if current_user
        render json: { message: 'Logged out successfully' }, status: :ok
      end
    end
  end
end
