# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    # Request helpers shared by the tests below. Pulled out of the test
    # class itself to keep it under Metrics/ClassLength.
    module OrdersControllerTestHelpers
      def auth_headers(user)
        token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        { 'Authorization' => "Bearer #{token}" }
      end

      def post_order(items:, user: nil)
        headers = user ? auth_headers(user) : {}
        post "/api/v1/events/#{@event.id}/orders", params: { items: items }, headers: headers, as: :json
      end

      def destroy_order(user:, reason: nil)
        params = reason ? { reason: reason } : {}
        delete "/api/v1/orders/#{orders(:paid_one).id}", params: params, headers: auth_headers(user), as: :json
      end

      def stub_refund
        stub_request(:post, 'https://api.stripe.com/v1/refunds')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: { id: 're_test_1', object: 'refund', status: 'succeeded' }.to_json
          )
      end
    end

    class OrdersControllerTest < ActionDispatch::IntegrationTest
      include OrdersControllerTestHelpers

      setup do
        @user = users(:one)
        @other = users(:two)
        @event = events(:one)
        @ga = ticket_types(:one)
      end

      test 'create requires authentication' do
        post_order(items: [{ ticket_type_id: @ga.id, quantity: 1 }])
        assert_response :unauthorized
      end

      test 'create returns a pending order' do
        post_order(items: [{ ticket_type_id: @ga.id, quantity: 2 }], user: @user)

        assert_response :created
        body = response.parsed_body
        assert_equal 'pending', body['status']
        assert_equal 1, body['bookings'].size
        assert_equal '59.98', body['total_amount'].to_s
      end

      test 'create rejects an oversized cart with the cap message' do
        post_order(items: [{ ticket_type_id: @ga.id, quantity: 99 }], user: @user)

        assert_response :unprocessable_entity
        assert_equal 'cap_exceeded', response.parsed_body['code']
      end

      test 'create reports remaining stock when sold out' do
        @ga.update!(quantity: 3)
        post_order(items: [{ ticket_type_id: @ga.id, quantity: 2 }], user: @user)

        assert_response :unprocessable_entity
        assert_equal 'sold_out', response.parsed_body['code']
      end

      test 'create returns the standard error envelope when items is missing' do
        post "/api/v1/events/#{@event.id}/orders", params: {}, headers: auth_headers(@user), as: :json

        assert_response :unprocessable_entity
        assert_equal 'invalid_items', response.parsed_body['code']
        assert response.parsed_body['error'].present?
      end

      test 'create returns the standard error envelope when items is not an array' do
        post_order(items: { ticket_type_id: @ga.id, quantity: 1 }, user: @user)

        assert_response :unprocessable_entity
        assert_equal 'invalid_items', response.parsed_body['code']
      end

      test 'create rejects an empty items array' do
        post_order(items: [], user: @user)

        assert_response :unprocessable_entity
        assert_equal 'invalid_items', response.parsed_body['code']
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

      test 'destroy cancels my paid order' do
        stub_refund
        events(:one).update!(date: 30.days.from_now)

        destroy_order(user: @user, reason: 'change_of_plans')

        assert_response :success
        assert_equal 'cancelled', response.parsed_body['status']
        assert_equal 'cancelled', orders(:paid_one).reload.status
      end

      test 'destroy refuses inside the cutoff window' do
        events(:one).update!(date: 2.hours.from_now, cancel_cutoff_hours: 24)

        destroy_order(user: @user)

        assert_response :unprocessable_entity
        assert_equal 'past_cutoff', response.parsed_body['code']
      end

      test 'destroy forbids cancelling another users order' do
        destroy_order(user: @other)

        assert_response :not_found
        assert_equal 'paid', orders(:paid_one).reload.status
      end

      test 'destroy requires authentication' do
        delete "/api/v1/orders/#{orders(:paid_one).id}", as: :json
        assert_response :unauthorized
      end
    end
  end
end
