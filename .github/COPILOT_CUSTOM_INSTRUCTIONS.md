# Copilot Instructions for Events_berlin

## Development Guidelines

Be an experienced fullstack software engineer, always use these guides:
- **Rails**: https://guides.rubyonrails.org/
- **Ruby**: https://www.ruby-lang.org/en/documentation/
- **Nextjs**: https://nextjs.org/docs
- **ActiveAdmin**: https://activeadmin.info/

- https://docs.rubocop.org/rubocop-rails/index.html

## Project Overview

Box2.0-up-1 is a Rails 7.1 application using Ruby 3.2.2, designed as a modern web application with enterprise features. The project is hosted on GitLab at `git@github.com:Kevspecial/Events_berlin.git` and follows Eventbrite (Website & App) organizational patterns.

## Architecture & Stack

### Core Framework
- **Rails 7.1** with PostgreSQL primary database (SQLite3 for development)
- **Modern Frontend**: Nextjs, Hotwire (Turbo + Stimulus), Importmap, CSS/JS bundling
- **Admin Interface**: ActiveAdmin with custom addons

### Key Dependencies & Patterns
- **Authentication**: Devise + CanCanCan authorization
- **Background Jobs**: Sidekiq with Redis and scheduled cron jobs  
- **Search**: Ransack + pg_search for PostgreSQL full-text search
- **UI Framework**: Font Awesome + Bootstrap (via cssbundling-rails)
- **PDF Generation**: WickedPDF for document processing


## Development Workflow

### Setup Commands
```bash
bin/setup                    # Initial project setup
bin/rails db:prepare         # Database setup
bundle install              # Install dependencies
```

### Key Development Tools
- **Linting**: RuboCop with `rubocop-rails-omakase` configuration
- **Security**: Brakeman for static analysis
- **Testing**: RSpec + Factory Bot + Capybara system tests
- **Debugging**: Pry-rails with byebug

### Docker Support
- Production-ready `Dockerfile` with Ruby 3.2.2 slim base
- Configured for PostgreSQL and includes build optimizations

## Project-Specific Conventions

### Gemfile Organization
The `Gemfile` is meticulously organized into functional sections with clear comments - maintain this structure when adding dependencies.


### Database Strategy
- PostgreSQL for production/staging with advanced features (pg_search, hairtrigger)
- Database naming: `event_berlin_development`

### CI/CD Pipeline
GitHub Actions workflow (`.github/workflows/ci.yml`) includes:
- Ruby security scanning (Brakeman)
- JavaScript dependency auditing (Importmap)
- Code linting (RuboCop)
- Automated testing

## Critical Files to Understand
- `Gemfile`: Comprehensive dependency management
- `config/application.rb`: Module name `Eventsberlin`
- `bin/setup`: Idempotent development environment setup
- `.rubocop.yml`: Inherits from omakase with customizations
