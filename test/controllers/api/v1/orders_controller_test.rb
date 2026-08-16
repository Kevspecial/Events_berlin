# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class OrdersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
        @other = users(:two)
        @event = events(:one)
        @ga = ticket_types(:one)
      end

      def auth_headers(user)
        token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        { 'Authorization' => "Bearer #{token}" }
      end

      test 'create requires authentication' do
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 1 }] }, as: :json
        assert_response :unauthorized
      end

      test 'create returns a pending order' do
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 2 }] },
             headers: auth_headers(@user), as: :json

        assert_response :created
        body = response.parsed_body
        assert_equal 'pending', body['status']
        assert_equal 1, body['bookings'].size
        assert_equal '59.98', body['total_amount'].to_s
      end

      test 'create rejects an oversized cart with the cap message' do
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 99 }] },
             headers: auth_headers(@user), as: :json

        assert_response :unprocessable_entity
        assert_equal 'cap_exceeded', response.parsed_body['code']
      end

      test 'create reports remaining stock when sold out' do
        @ga.update!(quantity: 3)
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 2 }] },
             headers: auth_headers(@user), as: :json

        assert_response :unprocessable_entity
        assert_equal 'sold_out', response.parsed_body['code']
      end

      test 'index lists only my orders' do
        get '/api/v1/orders', headers: auth_headers(@user), as: :json

        assert_response :success
        ids = response.parsed_body['orders'].map { |o| o['id'] }
        assert_includes ids, orders(:paid_one).id
        assert_not_includes ids, orders(:pending_two).id
      end

      test 'index is paginated' do
        get '/api/v1/orders', headers: auth_headers(@user), as: :json
        assert_response :success
        assert response.parsed_body.key?('meta')
      end

      test 'show returns my order with bookings and tickets' do
        get "/api/v1/orders/#{orders(:paid_one).id}", headers: auth_headers(@user), as: :json

        assert_response :success
        body = response.parsed_body
        assert_equal orders(:paid_one).id, body['id']
        assert_equal 2, body['bookings'].first['tickets'].size
      end

      test 'show forbids another users order' do
        get "/api/v1/orders/#{orders(:paid_one).id}", headers: auth_headers(@other), as: :json
        assert_response :not_found
      end

      test 'show exposes whether the order can still be cancelled' do
        get "/api/v1/orders/#{orders(:paid_one).id}", headers: auth_headers(@user), as: :json
        assert_includes [true, false], response.parsed_body['cancellable']
      end
    end
  end
end
