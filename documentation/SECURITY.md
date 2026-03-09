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

---

# Production Readiness Recommendations

## Critical — Must Fix Before Deploying

### 1. SSL/TLS Not Enforced
`config.force_ssl = true` is missing from `config/environments/production.rb`. All traffic will be unencrypted.

**Fix:** Add to `config/environments/production.rb`:
```ruby
config.force_ssl = true
config.ssl_options = { redirect: { status: 307 } }
```

### 2. Authentication Mismatch Between Frontend and Backend
The frontend (`frontend/src/lib/api.ts`) sends `Authorization: Bearer <token>`, but the Rails backend uses **cookie-based Devise sessions** — there is no JWT/token generation anywhere. Login returns user data but never issues a token. Authenticated API calls will silently fail.

**Fix:** Install `devise-jwt` gem and configure token-based auth (see "Option 1: JWT Token Authentication" above), or switch the frontend to cookie-based auth with `credentials: 'include'` on all Axios requests.

### 3. Puma Workers Disabled
In `config/puma.rb`, `workers` and `preload_app!` are commented out. Production will run single-process, unable to utilize multiple CPU cores.

**Fix:** Uncomment in `config/puma.rb`:
```ruby
workers ENV.fetch("WEB_CONCURRENCY") { 4 }
preload_app!
```

### 4. Redis Missing From Docker Compose
Sidekiq and ActionCable both require Redis in production (`config/cable.yml`, `config/initializers/sidekiq.rb`), but there is no Redis service in `docker-compose.yml` and no Sidekiq worker process defined.

**Fix:** Add to `docker-compose.yml`:
```yaml
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"

sidekiq:
  build: .
  command: bundle exec sidekiq
  depends_on:
    - db
    - redis
  environment:
    REDIS_URL: redis://redis:6379/0
    DATABASE_URL: postgres://postgres:postgres@db:5432/event_berlin_development
```

### 5. CI Tests Disabled
In `.github/workflows/ci.yml`, the test step is **commented out** (`# - name: Run tests`). Tests never execute in CI.

**Fix:** Uncomment the test step and ensure all tests pass before merging.

### 6. Content Security Policy Disabled
The CSP initializer (`config/initializers/content_security_policy.rb`) is entirely commented out — no XSS mitigation headers in production.

**Fix:** Uncomment and configure:
```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, "https://fonts.gstatic.com"
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, "https://fonts.googleapis.com"
    policy.connect_src :self
  end
end
```

### 7. Active Storage Uses Local Disk in Production
`config/environments/production.rb` sets `config.active_storage.service = :local`. Uploaded images will be lost on container restart.

**Fix:** Configure S3 (or equivalent) in `config/storage.yml`:
```yaml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: eu-central-1
  bucket: events-berlin-production
```
Then set in `config/environments/production.rb`:
```ruby
config.active_storage.service = :amazon
```

### 8. No Rate Limiting
No `rack-attack` or equivalent. API endpoints (login, signup, bookings) are vulnerable to brute force and abuse.

**Fix:** Add to `Gemfile`:
```ruby
gem 'rack-attack'
```
Then create `config/initializers/rack_attack.rb`:
```ruby
Rack::Attack.throttle("req/ip", limit: 300, period: 5.minutes) do |req|
  req.ip
end

Rack::Attack.throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
  req.ip if req.path == "/api/v1/login" && req.post?
end
```

### 9. Hardcoded Database Credentials
`config/database.yml` has `username: username` and `password: postgres` with only partial ENV usage in production.

**Fix:** Use ENV variables for all production credentials:
```yaml
production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
```

### 10. Secret Key in Plain Text
`tmp/local_secret.txt` contains what appears to be a secret key committed to the repo.

**Fix:** Remove the file, add it to `.gitignore`, and rotate the secret immediately.

---

## High — Should Fix Before Launch

### 11. No Email Delivery Configured
`app/mailers/application_mailer.rb` has `from: 'from@example.com'`. No SMTP/SendGrid/SES configuration exists in `production.rb`. Devise password reset, booking confirmations — none will send.

**Fix:** Configure an email provider in `config/environments/production.rb`:
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV.fetch('SMTP_PORT', 587),
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: :plain,
  enable_starttls_auto: true
}
config.action_mailer.default_url_options = { host: ENV['APP_HOST'] }
```

### 12. Booking Confirmation Not Wired Up
`app/jobs/booking_confirmation_job.rb` has `# TODO: Send confirmation email` — it only logs. The bookings controller also has the job call commented out.

**Fix:** Create `BookingMailer`, implement `confirmation_email`, and uncomment the job trigger in both `BookingConfirmationJob` and `BookingsController`.

### 13. BookingService Payment Integration Incomplete
`app/services/booking_service.rb` contains `# TODO: Integrate with payment service`. The `BookingService` creates bookings without payment — only the separate `CheckoutController` handles Stripe.

**Fix:** Either wire `BookingService` to `PaymentService`, or ensure all booking creation flows redirect through the checkout flow.

### 14. No API Pagination
`EventsController#index` returns `Event.all` — with thousands of events this will cause performance issues.

**Fix:** Add the `pagy` gem and paginate all list endpoints:
```ruby
gem 'pagy'
```

### 15. CORS Origins Fall Back to Localhost
`config/initializers/cors.rb` defaults to `http://localhost:*` if `CORS_ORIGINS` ENV is not set.

**Fix:** Ensure `CORS_ORIGINS` is set in production and remove the localhost fallback:
```ruby
origins(*ENV.fetch('CORS_ORIGINS').split(','))
```

### 16. No Error Monitoring
No Sentry, Honeybadger, Bugsnag, or equivalent. Production errors will go unnoticed.

**Fix:** Add to `Gemfile`:
```ruby
gem 'sentry-ruby'
gem 'sentry-rails'
```
Configure in `config/initializers/sentry.rb`:
```ruby
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.traces_sample_rate = 0.2
end
```

### 17. Frontend Image Config Hardcoded to Localhost
`frontend/next.config.js` only allows images from `localhost:3000`. Production domain not configured.

**Fix:** Update `remotePatterns` to use an environment variable or add the production domain.

### 18. No Health Check Endpoint
No `/health` or `/up` route for container orchestration, load balancers, or monitoring.

**Fix:** Add to `config/routes.rb`:
```ruby
get '/up', to: proc { [200, {}, ['OK']] }
```

### 19. Missing Database Indexes
The `events` table has no index on `date` (used by `upcoming`/`past` scopes) or `private`. The `bookings` table has no index on `payment_status`.

**Fix:** Add a migration:
```ruby
add_index :events, :date
add_index :events, :private
add_index :bookings, :payment_status
```

### 20. Docker Image Not Production-Optimized
The Dockerfile installs dev dependencies, mounts source code as volumes, and doesn't use multi-stage builds.

**Fix:** Create a `Dockerfile.production` with multi-stage builds, `RAILS_ENV=production`, asset precompilation, and no dev/test gems.

---

## Medium — Improve Before Scaling

| # | Issue | Action |
|---|-------|--------|
| 21 | Permissions Policy headers disabled | Uncomment `config/initializers/permissions_policy.rb` |
| 22 | Devise mailer sender is placeholder | Set `config.mailer_sender` to a real address |
| 23 | No `redis` gem in Gemfile | Add `gem 'redis'` — required for Sidekiq/ActionCable |
| 24 | No database backup strategy | Configure pg_dump cron or use managed database backups |
| 25 | `config.load_defaults 7.0` on Rails 7.1 | Update to `config.load_defaults 7.1` in `config/application.rb` |
| 26 | Private events visible in API | Filter private events in `EventPolicy::Scope#resolve` |
| 27 | No frontend tests | Add Jest/Vitest for unit tests, Playwright for E2E |
| 28 | Test coverage sparse | Write tests for User model, checkout flow, sessions, and payment |
| 29 | Node 16 in CI (EOL) | Update `.github/workflows/ci.yml` to Node 18+ |
| 30 | PostgreSQL version mismatch | Align CI (Postgres 11) with docker-compose (Postgres 12.5) |
| 31 | No logging/APM | Add structured logging and performance monitoring |
| 32 | Frontend `name` field not persisted | Add `name` column to `users` table or remove from signup form |

---

## What's Already Solid

- Rails 7.1 with PostgreSQL and proper foreign key constraints
- Devise authentication with bcrypt (12 stretches)
- Pundit authorization policies on all sensitive actions
- Stripe webhook signature verification in `CheckoutController`
- Parameter filtering for sensitive data (`filter_parameter_logging.rb`)
- Brakeman and RuboCop configured for static analysis
- Service objects for business logic separation
- Admin role assignment prevention on user creation
- Docker containerization for development
- TypeScript frontend with proper typing and React Query

## Recommended Priority Order

1. Fix auth (JWT or cookie-based) — app is non-functional without this
2. Enable SSL — one line in `production.rb`
3. Add Redis + Sidekiq worker to docker-compose
4. Enable Puma workers for production
5. Add `rack-attack` for rate limiting
6. Configure cloud storage (S3) for Active Storage
7. Set up email delivery (SendGrid/SES)
8. Add pagination (`pagy` gem)
9. Enable CSP headers
10. Uncomment CI tests and fix Node version
