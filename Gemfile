# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.2'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.1.5', '>= 7.1.5.2'
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'
# Use PostgreSQL as the database for Active Record
gem 'pg', '~> 1.4'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.0'
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

gem 'rack-cors'
gem 'rack-attack', '~> 6.7'
# Ensure rack is updated to mitigate known multipart/parser vulnerabilities
gem 'rack', '>= 3.1.18'
# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Devise is a flexible authentication solution for Rails
gem 'devise', '~> 4.9', '>= 4.9.3'
gem 'devise-jwt', '~> 0.11.0'
gem 'redis', '~> 5.0'

# Active Admin for administration interface
gem 'activeadmin'

# SASS support for Active Admin
gem 'sassc-rails'

# Authorization with Pundit
gem 'pundit', '~> 2.3'

# Jbuilder for JSON views
gem 'jbuilder', '~> 2.11'

# ActiveModel Serializers for API responses
gem 'active_model_serializers', '~> 0.10.0'

# Background jobs with Sidekiq
gem 'sidekiq', '~> 7.0'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem 'image_processing', '~> 1.2'

# Stripe for payment processing
gem 'stripe', '~> 10.0'

# Cloudinary for Active Storage
gem 'cloudinary', '~> 1.28'
gem 'activestorage-cloudinary-service', '~> 0.2'

# Error monitoring with Sentry
gem 'sentry-ruby', '~> 5.0'
gem 'sentry-rails', '~> 5.0'
gem 'sentry-sidekiq', '~> 5.0'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]

  gem 'brakeman', require: false         # Security scanner for Rails
  gem 'bundler-audit', require: false    # Check for vulnerable gems
  gem 'rubocop', require: false          # Ruby linter
  gem 'rubocop-capybara', require: false # RSpec-specific linting rules
  gem 'rubocop-performance', require: false # Performance-related linting rules
  gem 'rubocop-rails', require: false # Rails-specific linting rules
  # Optional: include rubocop-capybara in development if you use its cops
  # gem 'rubocop-capybara', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Preview emails in the browser during development
  gem 'letter_opener'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  # live reload
  gem 'guard-livereload', '~> 2.5', require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end
