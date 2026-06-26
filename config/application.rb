# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Eventsberlin
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Enable sessions and middleware needed for Active Admin
    # config.api_only = true # Commented out to enable sessions for Active Admin

    # Add session store configuration
    config.session_store :cookie_store, key: '_events_berlin_session'

    # Configure Active Job to use Sidekiq
    config.active_job.queue_adapter = :sidekiq

    # Ensure we have the necessary middleware for Active Admin
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
  end
end
