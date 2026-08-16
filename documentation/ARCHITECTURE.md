# Architecture Overview

This document serves as a critical, living template designed to equip agents with a rapid and comprehensive understanding of the codebase's architecture, enabling efficient navigation and effective contribution from day one. Update this document as the codebase evolves.

## 1. Project Structure

```
Events_berlin/
├── app/                          # Rails application code
│   ├── admin/                    # ActiveAdmin resource definitions
│   ├── controllers/
│   │   └── api/v1/               # JSON API controllers (frontend-facing)
│   ├── jobs/                     # Sidekiq background jobs
│   ├── mailers/                  # Action Mailer email templates
│   ├── models/                   # ActiveRecord models
│   ├── policies/                 # Pundit authorization policies
│   ├── serializers/              # ActiveModel::Serializers (JSON shape)
│   └── services/                 # Service objects (BookingService, PaymentService)
├── config/                       # Rails config (routes, database, environments)
├── db/                           # Migrations and schema
├── test/                         # Rails tests (models, controllers, services)
├── frontend/                     # Next.js 15 application
│   └── src/
│       ├── app/                  # Next.js App Router pages
│       ├── components/           # Reusable React components
│       ├── hooks/                # TanStack React Query hooks
│       ├── lib/                  # Axios instance and utilities (api.ts)
│       ├── providers/            # Context providers (AuthProvider)
│       ├── services/             # API call wrappers per domain
│       └── types/                # TypeScript type definitions
├── documentation/                # Project docs (PRD, API docs, security)
├── .github/                      # GitHub Actions CI/CD workflows
├── docker-compose.yml            # Full-stack local development
├── Dockerfile                    # Rails container
├── fly.toml                      # Fly.io deployment config
└── CLAUDE.md                     # AI agent instructions
```

## 2. High-Level System Diagram

```
[Browser User]
      |
      v
[Next.js Frontend :3001]  ---(Bearer token, Axios)--->  [Rails JSON API :3000]
                                                               |          |
                                                      [SQLite / PostgreSQL]  [Sidekiq + Redis]
                                                                                    |
                                                                          [BookingConfirmationJob]
                                                                                    |
                                                                             [Action Mailer]

[Admin User]  --->  [ActiveAdmin Dashboard :3000/admin]  --->  [Rails + PostgreSQL]

[Rails API]  --->  [Stripe API]  (payment intents, refunds, checkout sessions)
```

## 3. Core Components

### 3.1. Frontend

**Name:** Events Berlin Web App

**Description:** A Next.js 15 single-page application that lets users browse events, book tickets, and manage their profiles. Organizers can create and manage events. All data is fetched from the Rails JSON API using Axios with session-based Bearer token auth.

**Technologies:** Next.js 15, React 19, TypeScript, TailwindCSS 4, TanStack React Query, Axios

**Deployment:** Docker (local), Vercel-compatible (static export not used — SSR)

**Key directories:**
- `src/lib/api.ts` — Axios instance with auth interceptor; 401 clears localStorage and redirects to `/login`
- `src/services/` — domain-scoped API wrappers (auth, event, booking, user)
- `src/hooks/` — React Query hooks consuming service layer
- `src/providers/AuthProvider.tsx` — auth state from localStorage

### 3.2. Backend Services

#### 3.2.1. Rails JSON API

**Name:** Events Berlin API

**Description:** Rails 7.1 JSON-only API under `api/v1` namespace. Handles authentication, event management, booking/payment flows, and user management. All actions are authorized with Pundit policies.

**Technologies:** Ruby 3.2.2, Rails 7.1, Devise (session auth), Pundit (authorization), ActiveModel::Serializers, Sidekiq

**Deployment:** Docker / Fly.io

**Key conventions:**
- `BaseController` requires `authenticate_user!` and uses `null_session` CSRF protection
- Pundit `NotAuthorizedError` rescued as 403 in `BaseController`
- `BookingService` validates capacity and creates `Booking` in a transaction
- `PaymentService` wraps Stripe (payment intents, refunds, checkout session retrieval)
- Legacy web routes exist for Devise sessions but are not used by the production UI

#### 3.2.2. ActiveAdmin Dashboard

**Name:** Admin Panel

**Description:** Internal admin interface at `/admin` for managing users, events, bookings, and categories. Uses a separate `AdminUser` Devise scope.

**Technologies:** ActiveAdmin, Ransack

**Note:** Every model exposed in admin must define `ransackable_attributes` and `ransackable_associations`.

#### 3.2.3. Background Job Processor

**Name:** Sidekiq

**Description:** Processes asynchronous jobs. Currently used for `BookingConfirmationJob` which sends confirmation emails after a booking is created.

**Technologies:** Sidekiq, Redis, Action Mailer

## 4. Data Stores

### 4.1. Primary Database

**Name:** Application Database

**Type:** SQLite3 (development/test), PostgreSQL (CI/production)

**Purpose:** Stores all application data — users, events, bookings, payments.

**Key Tables:** `users`, `admin_users`, `events`, `venues`, `categories`, `ticket_types`, `bookings`, `attendings`, `invites`, `jwt_denylists`

**Note:** `config/database.yml.github` is swapped in by CI to use PostgreSQL.

### 4.2. Cache / Queue

**Name:** Redis

**Type:** Redis

**Purpose:** Sidekiq job queue and ActionCable pub/sub.

## 5. External Integrations / APIs

| Service | Purpose | Integration Method |
|---|---|---|
| Stripe | Payment processing — payment intents, refunds, checkout sessions | REST API via `stripe` gem + `PaymentService` |
| Action Mailer | Transactional emails (booking confirmations) | Rails built-in, triggered via Sidekiq jobs |

## 6. Deployment & Infrastructure

**Cloud Provider:** Fly.io (production), Docker Compose (local)

**Key Services:** Fly.io machines, PostgreSQL (managed), Redis

**CI/CD Pipeline:** GitHub Actions (`.github/workflows/`) — runs Rails tests and linting on push

**Local dev:**
```bash
docker compose up --build
docker compose exec web rails db:create db:migrate db:seed
# Frontend separately: cd frontend && npm run dev
```

## 7. Security Considerations

**Authentication:**
- Users: Devise session-based auth. Frontend stores token in `localStorage` and sends as `Authorization: Bearer <token>`.
- Admins: Separate `AdminUser` Devise scope at `/admin`.
- `jwt_denylists` table invalidates revoked tokens.

**Authorization:** Pundit policies in `app/policies/` — every API action checks policy; 403 on `NotAuthorizedError`.

**Role model:** `User` enum — `attendee (0)`, `organizer (1)`, `admin (2)`. Admin role cannot be assigned via API (`prevent_admin_role_assignment` validation). Use `user.skip_admin_validation = true` in seeds/console.

**CORS:** Controlled via `CORS_ORIGINS` env var (comma-separated allowed origins).

**Security tooling:** Brakeman (static analysis), bundler-audit (dependency CVEs), RuboCop.

**Data Encryption:** TLS in transit (Fly.io), Stripe handles PCI-scoped payment data.

## 8. Development & Testing Environment

**Local Setup:**
1. Copy `.env.example` to `.env` and fill in Stripe keys.
2. `docker compose up --build` (full stack) or run Rails + frontend separately.
3. `docker compose exec web rails db:create db:migrate db:seed`

**Rails Testing:**
```bash
bin/rails test                            # All tests
bin/rails test test/models/user_test.rb  # Single file
```

**Frontend Testing:**
```bash
cd frontend && npx jest  # Jest + React Testing Library
```

**Code Quality:**
```bash
bin/rubocop --parallel   # Ruby linting
bin/brakeman             # Security scan
bundle exec bundler-audit check --update  # Dependency audit
cd frontend && npm run lint  # ESLint
```

## 9. Future Considerations / Roadmap

Per [PRD.md](PRD.md), the following are explicitly **out of scope for v1**:
- Seat maps / reserved seating
- Dynamic pricing
- Multi-day / multi-session passes
- External marketplace integrations

Potential future architectural changes:
- Move from SQLite (dev) + PostgreSQL (prod) split to PostgreSQL everywhere to eliminate environment divergence.
- Add real-time notifications via ActionCable (Redis is already in the stack).
- Introduce background job for payment status reconciliation with Stripe webhooks.

## 10. Project Identification

**Project Name:** Events Berlin

**Repository:** `/home/kevspecial/rubyP/Events_berlin`

**Primary Contact:** Kevspecial (knwokike@gmail.com)

**Date of Last Update:** 2026-06-28

## 11. Glossary / Acronyms

| Term | Definition |
|---|---|
| API | Application Programming Interface — here refers to the `api/v1` JSON namespace |
| Pundit | Ruby gem for authorization via policy objects |
| Devise | Ruby gem for authentication (session management, password hashing) |
| ActiveAdmin | Rails engine for admin dashboards |
| Sidekiq | Background job processor backed by Redis |
| TanStack Query | React data-fetching and caching library (formerly React Query) |
| Booking | A user's reservation of a `TicketType` for an `Event`; statuses: `pending`, `confirmed`, `cancelled` |
| Payment | Financial record attached to a Booking; statuses: `unpaid`, `paid`, `failed`, `refunded` |
| Organizer | A `User` with `role: organizer` — can create and manage events |
| PRD | Product Requirements Document — defines v1 scope at `documentation/PRD.md` |

## Ticketing domain

```
User ──< Order ──< Booking ──< Ticket
              │        │
Event ────────┘        └── TicketType
  └──< TicketType
```

- **Order** — the payment. One order equals one Stripe session and one confirmation email.
- **Booking** — a line item: one ticket tier and a quantity within an order.
- **Ticket** — the scanable unit. One row per admitted person, with its own code and check-in state.

### Inventory

`Order.holding_inventory` is the source of truth for whether an order still holds stock: an
order holds inventory while it is `paid`, or `pending` and not yet past `expires_at`.
`Booking.holding_inventory` builds on it — it joins to `Order.holding_inventory` and additionally
excludes bookings cancelled on their own, since a booking can be cancelled independently of its
order. `TicketType#available_quantity` and `Event#available_capacity` both derive from
`Booking.holding_inventory`, so an abandoned cart releases its stock automatically when the hold
lapses — no cleanup job is required for correctness.

### Services

Each state transition lives in one service under `app/services/`:

| Service | Transition |
|---------|-----------|
| `Orders::CreationService` | cart → pending order (or paid, when free) |
| `Orders::CheckoutService` | pending order → Stripe session |
| `Orders::PaymentCompletionService` | webhook → paid + issuance (idempotent) |
| `Orders::CancellationService` | paid → cancelled + refund |
| `Tickets::IssuanceService` | paid order → ticket rows (idempotent) |
| `Tickets::PdfRenderer` | ticket → PDF bytes |
| `Tickets::CheckInService` | issued → checked_in (row-locked) |
