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

      test 'should create booking' do
        event = events(:one)
        ticket_type = ticket_types(:one)

        assert_difference('Booking.count') do
          post api_v1_event_bookings_url(event), params: {
            booking: {
              ticket_type_id: ticket_type.id,
              quantity: 1
            }
          }, as: :json
        end

        assert_response :created
      end
    end
  end
end
