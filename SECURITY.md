# Authentication & Security Guide

## Current Authentication Setup

The application currently uses Devise for session-based authentication. The API endpoints use `protect_from_forgery with: :null_session` which allows the API to work with both session-based and token-based authentication.

## CSRF Protection for API

The `protect_from_forgery with: :null_session` strategy:
- Resets the session instead of raising an exception when CSRF token is invalid
- Allows API endpoints to work without CSRF tokens
- Is appropriate for APIs that will be consumed by JavaScript frontends or mobile apps

### For Production: Recommended Authentication Approaches

#### Option 1: JWT Token Authentication (Recommended for API-only)

1. Add `devise-jwt` gem to Gemfile:
```ruby
gem 'devise-jwt'
```

2. Configure Devise for JWT:
```ruby
# config/initializers/devise.rb
config.jwt do |jwt|
  jwt.secret = Rails.application.credentials.devise_jwt_secret_key
  jwt.dispatch_requests = [
    ['POST', %r{^/login$}]
  ]
  jwt.revocation_requests = [
    ['DELETE', %r{^/logout$}]
  ]
  jwt.expiration_time = 1.day.to_i
end
```

3. Update User model:
```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :jwt_authenticatable, jwt_revocation_strategy: JWTDenylist
end
```

#### Option 2: API Token Authentication

1. Add token column to users table:
```ruby
rails generate migration AddAuthenticationTokenToUsers authentication_token:string:index
```

2. Generate and validate tokens in the User model

3. Use token-based authentication in API controllers

#### Option 3: OAuth 2.0

Consider using OAuth 2.0 with gems like:
- `doorkeeper` for OAuth 2.0 provider
- `omniauth` for OAuth 2.0 client

## Current Security Measures

✅ User authentication with Devise
✅ Authorization with Pundit policies
✅ SQL injection protection (ActiveRecord parameterized queries)
✅ Mass assignment protection (strong parameters)
✅ XSS protection (Rails default)
✅ Session security (encrypted cookies)

## Security Best Practices Implemented

1. **Strong Parameters**: All controllers use strong parameters to prevent mass assignment
2. **Authorization**: Pundit policies ensure users can only access their own resources
3. **Password Security**: Devise handles secure password hashing with bcrypt
4. **Database Indexes**: Indexes added for frequently queried fields
5. **Input Validation**: Model validations prevent invalid data

## Future Security Enhancements

- [ ] Implement rate limiting (e.g., with `rack-attack`)
- [ ] Add API versioning
- [ ] Implement proper JWT or API token authentication
- [ ] Add request/response logging
- [ ] Implement IP whitelisting for admin actions
- [ ] Add two-factor authentication
- [ ] Regular security audits with Brakeman
- [ ] Keep dependencies updated with bundler-audit
