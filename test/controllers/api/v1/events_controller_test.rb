require 'test_helper'

module Api
  module V1
    class EventsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @event = events(:one)
        @user = users(:one)
      end

      test 'should get index' do
        get api_v1_events_url, as: :json
        assert_response :success
      end

      test 'should show event' do
        get api_v1_event_url(@event), as: :json
        assert_response :success
      end

      test 'should create event when authenticated as organizer' do
        @user.update(role: :organizer)
        sign_in @user

        assert_difference('Event.count') do
          post api_v1_events_url, params: {
            event: {
              name: 'New Event',
              description: 'Test event',
              location: 'Berlin',
              date: 1.week.from_now
            }
          }, as: :json
        end

        assert_response :created
      end
    end
  end
end
