# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class SessionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = User.create!(
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: :attendee
        )
      end

      teardown do
        @user&.destroy
      end

      test 'login returns token and user on valid credentials' do
        post api_v1_login_url,
             params: { email: 'test@example.com', password: 'password123' },
             as: :json

        assert_response :ok
        body = response.parsed_body
        assert body.key?('token'), "Response should include 'token' key"
        assert body.key?('user'), "Response should include 'user' key"
        assert_not_empty body['token'], "Token should not be empty"
        assert_equal @user.id, body['user']['id']
        assert_equal 'test@example.com', body['user']['email']
        assert_equal 'attendee', body['user']['role']
      end

      test 'login returns 401 on invalid password' do
        post api_v1_login_url,
             params: { email: 'test@example.com', password: 'wrongpassword' },
             as: :json

        assert_response :unauthorized
        body = response.parsed_body
        assert body.key?('error')
      end

      test 'login returns 401 for non-existent email' do
        post api_v1_login_url,
             params: { email: 'nobody@example.com', password: 'password123' },
             as: :json

        assert_response :unauthorized
      end

      test 'token is valid JWT format' do
        post api_v1_login_url,
             params: { email: 'test@example.com', password: 'password123' },
             as: :json

        assert_response :ok
        token = response.parsed_body['token']
        # JWT format: three Base64url segments separated by dots
        parts = token.split('.')
        assert_equal 3, parts.length, "Token should be a JWT with 3 parts (header.payload.signature)"
      end
    end
  end
end
