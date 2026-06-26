# frozen_string_literal: true

require 'test_helper'

class RateLimitingTest < ActionDispatch::IntegrationTest
  test 'blocks login after 5 failed attempts from same IP' do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    6.times do |i|
      post '/api/v1/login',
           params: { email: 'test@example.com', password: 'wrong' }.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'REMOTE_ADDR' => '1.2.3.4'
           }
    end
    assert_equal 429, response.status
  end
end
