# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'webmock/minitest'

# No test may reach the network. Stripe is stubbed per-test.
WebMock.disable_net_connect!(allow_localhost: true)

# The environment has no real Stripe key configured. The Stripe client
# raises before ever reaching the network if api_key is nil, so tests that
# stub Stripe HTTP calls with WebMock still need a placeholder key set.
Stripe.api_key ||= 'sk_test_placeholder'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
