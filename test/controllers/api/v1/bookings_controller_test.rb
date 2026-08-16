require 'test_helper'

module Api
  module V1
    class BookingsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @booking = bookings(:one)
        @user = users(:one)
        sign_in @user
      end

      test 'should get index' do
        get api_v1_bookings_url, as: :json
        assert_response :success
      end

      test 'should show booking' do
        get api_v1_booking_url(@booking), as: :json
        assert_response :success
      end
    end
  end
end
