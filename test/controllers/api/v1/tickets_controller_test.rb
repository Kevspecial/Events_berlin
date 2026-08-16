# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class TicketsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @ticket = tickets(:issued_one) # belongs to bookings(:one) → users(:one)
        @owner = users(:one)
        @stranger = users(:two)
      end

      def auth_headers(user)
        token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        { 'Authorization' => "Bearer #{token}" }
      end

      test 'download requires authentication' do
        get "/api/v1/tickets/#{@ticket.code}/download", as: :json
        assert_response :unauthorized
      end

      test 'owner downloads a PDF' do
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@owner)

        assert_response :success
        assert_equal 'application/pdf', response.media_type
        assert response.body.start_with?('%PDF')
      end

      test 'download sets a filename from the code' do
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@owner)
        assert_match(/ticket-#{@ticket.code}\.pdf/, response.headers['Content-Disposition'])
      end

      test 'a stranger cannot download someone elses ticket' do
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@stranger)
        assert_response :forbidden
      end

      test 'an unknown code returns not found' do
        get '/api/v1/tickets/EB-000000000000/download', headers: auth_headers(@owner)
        assert_response :not_found
      end

      test 'a cancelled ticket cannot be downloaded' do
        @ticket.update!(status: 'cancelled', cancelled_at: Time.current)
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@owner)

        assert_response :unprocessable_entity
      end
    end
  end
end
