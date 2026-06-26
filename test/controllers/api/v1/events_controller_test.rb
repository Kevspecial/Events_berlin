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

      test 'index returns paginated events with meta' do
        get api_v1_events_url, as: :json
        assert_response :success
        body = JSON.parse(response.body)
        assert body.key?('events'), "Response should include 'events' key"
        assert body.key?('meta'), "Response should include 'meta' key"
        assert body['meta'].key?('count'), "Meta should include 'count' key"
        assert body['meta'].key?('page'), "Meta should include 'page' key"
        assert body['meta'].key?('pages'), "Meta should include 'pages' key"
      end
    end
  end
end
