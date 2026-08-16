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

      test 'organiser previews a ticket without consuming it' do
        organiser = @ticket.event.creator
        get "/api/v1/tickets/#{@ticket.code}", headers: auth_headers(organiser), as: :json

        assert_response :success
        assert_equal @ticket.code, response.parsed_body['code']
        assert_equal 'issued', @ticket.reload.status
      end

      # Same fixture overlap as above: @owner is both holder and organiser of
      # @ticket by default, so reassign the event's creator to a third user
      # to prove a pure holder (no organiser role) is refused the preview.
      test 'holder cannot preview for check-in' do
        @ticket.event.update!(creator: users(:two))

        get "/api/v1/tickets/#{@ticket.code}", headers: auth_headers(@owner), as: :json
        assert_response :forbidden
      end

      test 'organiser checks a ticket in' do
        organiser = @ticket.event.creator
        @ticket.event.update!(date: 1.hour.from_now)

        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json

        assert_response :success
        assert_equal 'checked_in', response.parsed_body['status']
        assert @ticket.reload.checked_in?
      end

      test 'a second check-in returns conflict' do
        organiser = @ticket.event.creator
        @ticket.event.update!(date: 1.hour.from_now)

        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json
        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json

        assert_response :conflict
        assert_equal 'already_checked_in', response.parsed_body['code']
      end

      test 'checking in a cancelled ticket is unprocessable' do
        organiser = @ticket.event.creator
        @ticket.event.update!(date: 1.hour.from_now)
        @ticket.update!(status: 'cancelled', cancelled_at: Time.current)

        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json

        assert_response :unprocessable_entity
        assert_equal 'cancelled', response.parsed_body['code']
      end

      # NOTE: @ticket.event.creator (i.e. @owner, users(:one)) is BOTH the
      # ticket holder and the event organiser in the shared fixtures, so a
      # naive test posting as @owner would legitimately succeed as the
      # organiser and would not prove anything about holders. To prove a
      # *pure* holder (no organiser role) is refused, we reassign the event's
      # creator to a third user for the duration of this test, leaving
      # @owner as holder-only.
      test 'the holder cannot check in their own ticket' do
        @ticket.event.update!(creator: users(:two), date: 1.hour.from_now)

        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(@owner), as: :json

        assert_response :forbidden
        assert_equal 'issued', @ticket.reload.status
      end

      test 'an unknown code returns not found on check-in' do
        organiser = @ticket.event.creator
        post '/api/v1/tickets/EB-000000000000/check_in', headers: auth_headers(organiser), as: :json

        assert_response :not_found
      end
    end
  end
end
