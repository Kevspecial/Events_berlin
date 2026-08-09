# Copilot Instructions for Events_berlin

Be an experienced fullstack software engineer, always use these guides:
- **Rails**: https://guides.rubyonrails.org/
- **Ruby**: https://www.ruby-lang.org/en/documentation/
- **Nextjs**: https://nextjs.org/docs
- **ActiveAdmin**: https://activeadmin.info/

- https://docs.rubocop.org/rubocop-rails/index.html

## Project Overview

Events Berlin is a full-stack Eventbrite-style platform for Berlin events. The backend is a Rails 7.1 JSON API (Ruby 3.2.2) and the frontend is a separate Next.js 15 app (React 19, TypeScript, TailwindCSS 4) in the `/frontend` directory.

- **Frontend**: http://localhost:3001
- **Rails API**: http://localhost:3000
- **Admin Panel**: http://localhost:3000/admin

## Commands

### Rails Backend

```bash
bundle install
bin/rails db:create db:migrate db:seed   # DB setup
bin/rails server                          # Start Rails (port 3000)
bundle exec sidekiq                       # Start background job processor
bin/rails test                            # Run all tests
bin/rails test test/models/user_test.rb  # Run a single test file
bin/rubocop --parallel                    # Lint
bin/brakeman                             # Security scan
bundle exec bundler-audit check --update # Dependency audit
```

### Next.js Frontend

```bash
cd frontend
npm install
npm run dev    # Start dev server (port 3001, uses Turbopack)
npm run build  # Production build
npm run lint   # ESLint
```

### Docker (recommended for full-stack)

```bash
docker compose up --build
docker compose exec web rails db:create db:migrate db:seed
```

## Architecture

### Dual Rails Routing

The app has two distinct route groups:

1. **Legacy web routes** — `resources :events`, `resources :attendings`, etc. These use standard Rails controllers with Devise session auth and are effectively unused by the production UI.
2. **API routes** — `namespace :api > namespace :v1` — all controllers under `app/controllers/api/v1/`. These serve the Next.js frontend. `BaseController` requires `authenticate_user!` (Devise) but uses `null_session` CSRF protection.

### Authentication Flow

The API uses session-based authentication (Devise), but the frontend stores the auth token in `localStorage` and sends it as `Authorization: Bearer <token>` on every request (`frontend/src/lib/api.ts`). A 401 response clears localStorage and redirects to `/login`.

Two separate user models exist:
- `User` — attendees, organizers, admins; authenticated via API
- `AdminUser` — ActiveAdmin dashboard only; separate Devise scope

### User Roles

`User` has an enum role: `attendee (0)`, `organizer (1)`, `admin (2)`. Admin role **cannot** be assigned on creation through the API — validated by `prevent_admin_role_assignment`. To bypass in seeds or console, set `user.skip_admin_validation = true`.

### Service Objects

- `BookingService` — validates ticket/event capacity and creates `Booking` in a transaction
- `PaymentService` — wraps Stripe API calls (payment intents, refunds, checkout session retrieval)

Booking statuses: `pending` / `confirmed` / `cancelled`
Payment statuses: `unpaid` / `paid` / `failed` / `refunded`

### Frontend Data Layer

- `frontend/src/lib/api.ts` — Axios instance with auth interceptor
- `frontend/src/services/` — API call wrappers per domain (auth, event, booking, user)
- `frontend/src/hooks/` — TanStack React Query hooks consuming the service layer
- `frontend/src/providers/AuthProvider.tsx` — Context provider managing auth state from localStorage

### ActiveAdmin

Admin resources live in `app/admin/`. These files use DSL blocks that trigger RuboCop's `Metrics/BlockLength` — this is expected and suppressed. Every model exposed in admin must define `ransackable_attributes` and `ransackable_associations` class methods to enable admin search.

## Environment Variables

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection (CI/production) |
| `REDIS_URL` | Sidekiq + ActionCable |
| `STRIPE_SECRET_KEY` | Stripe backend key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing |
| `FRONTEND_URL` | Used for Stripe redirect URLs |
| `CORS_ORIGINS` | Comma-separated allowed origins |
| `NEXT_PUBLIC_API_URL` | API URL for frontend (default: `http://localhost:3000/api/v1`) |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe frontend key |

Copy `.env.example` to `.env` and fill in keys before running locally.

## Key Conventions

- API controllers render JSON only — no HTML views under `api/v1/`
- Pundit policies in `app/policies/` authorize all API actions; `BaseController` rescues `Pundit::NotAuthorizedError` as 403
- ActiveModel::Serializers in `app/serializers/` control JSON shape
- Background jobs (Sidekiq) in `app/jobs/` — `BookingConfirmationJob` sends confirmation emails
- Database: SQLite3 locally (dev/test), PostgreSQL in CI (`config/database.yml.github` is swapped in by CI)
- PRD at `documentation/PRD.md` defines v1 scope — do not add seat maps, dynamic pricing, multi-day passes, or external marketplace integrations


## If unsure
- Ask a short clarifying question and include the precise file and line range you plan to change.