# Copilot Instructions for Box2.0-up-1

## Development Guidelines

Be an experienced fullstack software engineer, always use these guides:
- **Rails**: https://guides.rubyonrails.org/
- **Ruby**: https://www.ruby-lang.org/en/documentation/
- **Vue.js**: https://vuejs.org/guide/introduction.html
- **ActiveAdmin**: https://activeadmin.info/

## Project Overview

Box2.0-up-1 is a Rails 7.2 application using Ruby 3.1.2, designed as a modern web application with enterprise features. The project is hosted on GitLab at `git.hvd-bb.de/hvd/box2.0-up-1` and follows HVD organizational patterns.

## Architecture & Stack

### Core Framework
- **Rails 7.2** with PostgreSQL primary database (SQLite3 for development)
- **Modern Frontend**: Hotwire (Turbo + Stimulus), Importmap, CSS/JS bundling
- **Template Engine**: Slim-rails for views
- **Admin Interface**: ActiveAdmin with custom addons

### Key Dependencies & Patterns
- **Authentication**: Devise + CanCanCan authorization + Office365 SSO
- **Background Jobs**: Sidekiq with Redis and scheduled cron jobs  
- **Search**: Ransack + pg_search for PostgreSQL full-text search
- **UI Framework**: Font Awesome + Tailwind (via cssbundling-rails)
- **PDF Generation**: WickedPDF for document processing
- **Custom HVD Gems**: `lku` (internal) and `omniauth-office365`

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
- Production-ready `Dockerfile` with Ruby 3.1.2 slim base
- Configured for PostgreSQL and includes build optimizations

## Project-Specific Conventions

### Gemfile Organization
The `Gemfile` is meticulously organized into functional sections with clear comments - maintain this structure when adding dependencies.

### HVD Integration Points
- Custom git source for HVD internal gems: `git_source(:hvd)`
- LKU gem integration (currently commented, enable in production)
- Office365 authentication via custom omniauth provider

### Database Strategy
- PostgreSQL for production/staging with advanced features (pg_search, hairtrigger)
- SQLite3 for development convenience
- Database naming: `box2_0_up_1_development`

### CI/CD Pipeline
GitHub Actions workflow (`.github/workflows/ci.yml`) includes:
- Ruby security scanning (Brakeman)
- JavaScript dependency auditing (Importmap)
- Code linting (RuboCop)
- Automated testing

## Critical Files to Understand
- `Gemfile`: Comprehensive dependency management with HVD-specific patterns
- `config/application.rb`: Module name `Box20Up1`
- `bin/setup`: Idempotent development environment setup
- `.rubocop.yml`: Inherits from omakase with customizations
