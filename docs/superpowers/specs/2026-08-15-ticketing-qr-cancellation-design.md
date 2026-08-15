# Ticketing, QR Tickets, Cancellation & Waitlist — Design

**Date:** 2026-08-15
**Status:** Approved for planning
**Scope:** Complete the attendee purchase journey — buy multiple tickets across tiers, receive per-ticket QR codes as downloadable PDFs, cancel with automatic refund, and join a waitlist when sold out.

---

## 1. Context

`Events_berlin` today models a purchase as a single `Booking` row carrying a `quantity`. Stripe checkout works, but:

- There is no individual ticket entity, so there is nothing to put a QR code on.
- A buyer cannot combine ticket tiers (2 × GA + 1 × VIP) in one payment.
- `PATCH /bookings/:id/cancel` only flips a status string — no refund, no cutoff rule, no inventory release.
- Nothing is generated, emailed, or downloadable after payment.

This design closes those gaps while preserving the existing `Booking` table, its ActiveAdmin resource, its Pundit policy, and its serializer.

### Eventbrite comparison

Eventbrite separates **Order** (the payment) from **Attendee/Ticket** (the scanable unit). Our current model collapses both into `Booking`. This design introduces the missing layers without a disruptive rename.

---

## 2. Goals and non-goals

### Goals

1. An attendee can select quantities across multiple ticket tiers for one event and pay once.
2. Each ticket purchased is an individually addressable row with its own QR code.
3. Tickets are delivered as one PDF per ticket, emailed on purchase and downloadable any time.
4. An attendee can cancel an order before a per-event cutoff and receive an automatic Stripe refund.
5. Free events work end to end without touching Stripe.
6. Organizers can validate and check in a ticket through an API, with double-scan protection.
7. When an event or tier is sold out, attendees can join a waitlist and are offered freed inventory automatically.

### Non-goals

- **Ticket transfer / reassignment.** Per-ticket rows make this straightforward later, but it needs claim tokens, invite emails, and PDF re-issuance — a separate slice.
- **Per-ticket attendee names.** Buyer-only capture for this build. Tickets are bearer instruments.
- **Scanner UI.** Check-in is API-only; no camera page. Demonstrable via `curl`/Postman.
- **Multi-event cart.** One order belongs to exactly one event.
- **Seat selection / reserved seating.**
- **Partial (per-ticket) cancellation.** Cancellation operates on the whole order.

---

## 3. Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | One QR per **ticket**, not per order | Enables individual check-in and future transfer |
| 2 | New `Order` wraps existing `Booking`; `Booking` becomes a line item | Preserves shipped code, admin, policies, serializers |
| 3 | Cart spans tiers within a **single event** | Matches Eventbrite; avoids multi-event cart complexity |
| 4 | **Buyer-only** attendee capture | Smaller checkout form; tickets are bearer instruments |
| 5 | **Whole-order** cancel with full refund | Avoids partial-refund and Stripe fee edge cases |
| 6 | Cancel cutoff: `events.cancel_cutoff_hours`, default **24** | Per-event override, familiar pattern |
| 7 | Ticket code: `EB-` + 12-char Crockford base32 | ~2^60 entropy, no ambiguous glyphs, typeable fallback |
| 8 | QR payload is the **bare code**, not a URL | Scanner-agnostic, offline-safe, no domain lock-in |
| 9 | PDF via **Prawn + prawn-qrcode** | Pure Ruby; no `wkhtmltopdf` binary in the Docker image |
| 10 | Browser QR via **`qrcode.react`** | Client-side render; code is the source of truth, not an image |
| 11 | Inventory held on order creation, released after **15 min** if unpaid | Prevents oversell without Redis locks |
| 12 | **Free events** bypass Stripe entirely | Order is born `paid`; one shared issuance path downstream |
| 13 | Max tickets per order: `events.max_tickets_per_order`, default **10** | Anti-scalping; nullable means unlimited |
| 14 | Sold out → **waitlist** with FIFO offers | Explicitly requested; scoped as its own phase |
| 15 | Check-in is **API-only** | Full state machine and authorization without a frontend detour |

---

## 4. Data model

### 4.1 New table: `orders`

The purchase transaction. One order = one payment = one confirmation email.

| Column | Type | Constraints |
|---|---|---|
| `id` | bigint | pk |
| `user_id` | bigint | fk → users, not null |
| `event_id` | bigint | fk → events, not null |
| `status` | string | not null, default `'pending'` |
| `total_amount` | decimal(10,2) | not null |
| `currency` | string(3) | not null, default `'eur'` |
| `stripe_checkout_session_id` | string | unique, nullable |
| `stripe_payment_intent_id` | string | unique, nullable |
| `payment_status` | string | not null, default `'unpaid'` |
| `expires_at` | datetime | not null |
| `paid_at` | datetime | nullable |
| `cancelled_at` | datetime | nullable |
| `refunded_at` | datetime | nullable |
| `refund_reason` | string | nullable |
| `created_at` / `updated_at` | datetime | not null |

**`status`:** `pending` → `paid` | `expired` | `cancelled` | `refunded`
**`payment_status`:** `unpaid` | `paid` | `refunded` | `failed` (mirrors Stripe's view)

Indexes: `user_id`, `event_id`, `status`, `expires_at`, unique on `stripe_checkout_session_id`, unique on `stripe_payment_intent_id`.

`total_amount` is frozen at creation so later price edits by the organizer never rewrite history.

### 4.2 Changed table: `bookings`

Meaning narrows from "the order" to "one ticket-type line inside an order." Columns are otherwise unchanged.

**Add:** `order_id` bigint, fk → orders, not null (after backfill), indexed.

**Drop in a follow-up migration** once `Order` owns them: `stripe_checkout_session_id`, `stripe_payment_intent_id`, `payment_status`, `paid_at`.

**Keep:** `user_id`, `event_id`, `ticket_type_id`, `quantity`, `total_price`, `status`, timestamps.

`booking.status` now cascades from its order: a `paid` order marks all its bookings `confirmed`; a `cancelled` order marks them `cancelled`.

### 4.3 New table: `tickets`

The scanable unit — one row per admitted person.

| Column | Type | Constraints |
|---|---|---|
| `id` | bigint | pk |
| `booking_id` | bigint | fk → bookings, not null |
| `code` | string(15) | not null, unique |
| `status` | string | not null, default `'issued'` |
| `checked_in_at` | datetime | nullable |
| `checked_in_by_id` | bigint | fk → users, nullable |
| `cancelled_at` | datetime | nullable |
| `created_at` / `updated_at` | datetime | not null |

**`status`:** `issued` → `checked_in` | `cancelled`

Indexes: unique on `code`, `booking_id`, `status`, composite `(booking_id, status)`.

### 4.4 New table: `waitlist_entries`

| Column | Type | Constraints |
|---|---|---|
| `id` | bigint | pk |
| `user_id` | bigint | fk → users, not null |
| `event_id` | bigint | fk → events, not null |
| `ticket_type_id` | bigint | fk → ticket_types, nullable while `waiting` (null = any tier); **required once `offered`** |
| `quantity` | integer | not null, default 1 |
| `status` | string | not null, default `'waiting'` |
| `position` | integer | not null |
| `claim_token` | string | unique, nullable |
| `offered_at` | datetime | nullable |
| `claim_expires_at` | datetime | nullable |
| `claimed_at` | datetime | nullable |
| `created_at` / `updated_at` | datetime | not null |

**`status`:** `waiting` → `offered` → `claimed` | `expired` | `released`

A `waiting` entry may leave `ticket_type_id` null to mean "any tier." The promotion service **resolves that to a concrete tier at the moment it makes an offer**, so every `offered` entry names exactly one `ticket_type`. This is what makes the inventory hold in §5 well defined — a model validation enforces `ticket_type_id` presence when status is `offered`.

Indexes:
- `(event_id, ticket_type_id, status, position)` — the FIFO promotion scan
- unique on `claim_token`
- partial unique on `(user_id, event_id, ticket_type_id)` `WHERE status IN ('waiting','offered')` — one live entry per user per tier, while still allowing a user to rejoin after an entry lapses

### 4.5 Changed table: `events`

**Add:**
- `cancel_cutoff_hours` integer, default `24`, nullable (null = cancellation always allowed)
- `max_tickets_per_order` integer, default `10`, nullable (null = unlimited)

### 4.6 Relationships

```
User ──< Order ──< Booking ──< Ticket
              │        │
Event ────────┘        └── TicketType
  └──< TicketType
  └──< WaitlistEntry
```

### 4.7 Backfill migration

Existing bookings must not break. In one transaction:

1. Create `orders` and `tickets` tables; add `order_id` to `bookings` as nullable.
2. For each existing `Booking`, create a shim `Order` (same `user_id`, `event_id`, `total_amount = booking.total_price`, status derived from the booking's `payment_status`/`status`, Stripe ids copied across, `expires_at = created_at + 15.min`) and point the booking at it.
3. For each booking with a live status, create `quantity` `Ticket` rows with generated codes.
4. Set `bookings.order_id` to `NOT NULL`.

The Stripe column drops on `bookings` ship in a **separate later migration**, after the new code has run in production, so a rollback never loses payment identifiers.

---

## 5. Inventory accounting

The single source of truth for "can I sell this?" is `TicketType#available_quantity`.

Inventory is held by:
1. Bookings whose order is `paid`.
2. Bookings whose order is `pending` **and** not yet expired.
3. Waitlist entries in `offered` status (an outstanding offer reserves stock).

```ruby
# app/models/order.rb
scope :holding_inventory, lambda {
  where(status: 'paid').or(where(status: 'pending').where(expires_at: Time.current..))
}

# app/models/booking.rb
scope :holding_inventory, -> { joins(:order).merge(Order.holding_inventory) }

# app/models/waitlist_entry.rb
scope :offered, -> { where(status: 'offered').where(claim_expires_at: Time.current..) }

# app/models/ticket_type.rb
def available_quantity
  quantity - bookings.holding_inventory.sum(:quantity) - waitlist_entries.offered.sum(:quantity)
end
```

An offer past its `claim_expires_at` stops holding inventory the moment it lapses, even before `WaitlistOfferExpiryJob` gets around to relabelling the row. The job is bookkeeping; the scope is the truth.

`Event#available_capacity` follows the same join when `capacity` is set.

**Race protection.** Order creation wraps availability checks and inserts in a single transaction that takes a row lock on each `TicketType` (`lock!`) before reading `available_quantity`. This serialises concurrent buyers of the same tier without introducing Redis.

---

## 6. Domain services

Each service is a single-purpose object with a `call` method, following the existing `BookingService` convention.

| Service | Responsibility |
|---|---|
| `Orders::CreationService` | Validate cart (tiers belong to event, quantities > 0, per-order cap, availability), lock tiers, create `Order` + `Booking` line items in one transaction. Returns `pending` order — or `paid` immediately when total is zero. |
| `Orders::CheckoutService` | Build a Stripe Checkout Session with one line item per booking. Persists `stripe_checkout_session_id`. Refuses non-`pending`/expired orders. |
| `Orders::PaymentCompletionService` | Invoked by the webhook. Idempotently flips order to `paid`, stamps `paid_at` and `stripe_payment_intent_id`, cascades bookings to `confirmed`, then calls issuance. |
| `Tickets::IssuanceService` | Creates `SUM(booking.quantity)` tickets with unique codes. Idempotent: no-op if tickets already exist for the order. |
| `Tickets::PdfRenderer` | Renders one ticket to a PDF byte string via Prawn + prawn-qrcode. |
| `Orders::CancellationService` | Enforces cutoff, issues `Stripe::Refund`, cancels order + bookings + tickets, releases inventory, enqueues waitlist promotion. |
| `Tickets::CheckInService` | State machine guard for scanning. Returns a typed result (`:ok`, `:already_checked_in`, `:cancelled`, `:not_found`, `:wrong_event`). |
| `Waitlist::PromotionService` | On freed inventory, offers stock FIFO to `waiting` entries, mints claim tokens, enqueues offer emails. **Offers are all-or-nothing:** an entry requesting more than the freed quantity is skipped (it keeps its position) and the scan continues to the next entry. No partial fills, so a buyer is never offered fewer tickets than they asked for. |
| `Waitlist::ClaimService` | Exchanges a valid claim token for a `pending` order with inventory already reserved. |

### Background jobs

| Job | Trigger | Work |
|---|---|---|
| `OrderExpiryJob` | Recurring (every minute) | Marks `pending` orders past `expires_at` as `expired`, releases inventory, enqueues `WaitlistPromotionJob` |
| `OrderConfirmationJob` | After issuance | Sends `OrderMailer#confirmation` with PDF attachments |
| `WaitlistPromotionJob` | Inventory freed | Runs `Waitlist::PromotionService` for the affected tier |
| `WaitlistOfferExpiryJob` | Recurring | Expires stale offers, releases their hold, promotes the next entry |

Sidekiq 7 and Redis are already wired (`config/sidekiq.yml`, `docker-compose.yml`). Recurring jobs use `sidekiq-cron`.

---

## 7. Flows

### 7.1 Paid purchase

```
Attendee picks quantities on /events/:id
  └─ POST /api/v1/events/:id/orders   { items: [{ticket_type_id, quantity}, ...] }
       └─ Orders::CreationService
            ├─ lock tiers, verify availability + per-order cap
            ├─ create Order(status: pending, expires_at: now+15m)
            └─ create one Booking per tier
  └─ POST /api/v1/orders/:id/checkout
       └─ Orders::CheckoutService → Stripe session → { checkout_url }
  └─ Browser redirects to Stripe
  └─ Stripe → POST /api/v1/checkout/webhook  (checkout.session.completed)
       └─ Orders::PaymentCompletionService
            ├─ order → paid, bookings → confirmed
            ├─ Tickets::IssuanceService → N tickets with codes
            └─ OrderConfirmationJob → email + PDFs
  └─ /checkout/success polls GET /api/v1/orders/:id until status == 'paid'
```

### 7.2 Free purchase

```
POST /api/v1/events/:id/orders
  └─ Orders::CreationService detects total_amount.zero?
       ├─ order created directly as paid, paid_at = now
       ├─ Tickets::IssuanceService (inline)
       └─ OrderConfirmationJob
  └─ Response includes status: 'paid' → frontend skips Stripe, goes to order detail
```

### 7.3 Expiry

`OrderExpiryJob` runs every minute: `pending` orders with `expires_at < now` become `expired`. Their bookings stop holding inventory automatically (the `holding_inventory` scope excludes them), and `WaitlistPromotionJob` is enqueued for each affected tier.

### 7.4 Cancellation and refund

```
DELETE /api/v1/orders/:id  { reason }
  └─ OrderPolicy#cancel?  (owner or admin)
  └─ Orders::CancellationService
       ├─ reject unless status == 'paid'
       ├─ reject if event.cancel_cutoff_hours && event.date - cutoff < now  → 422
       ├─ if stripe_payment_intent_id present → Stripe::Refund.create(...)
       ├─ order → cancelled, cancelled_at, refund_reason
       ├─ bookings → cancelled, tickets → cancelled
       └─ enqueue WaitlistPromotionJob
  └─ Stripe → webhook charge.refunded
       └─ order → refunded, refunded_at stamped
```

Free orders skip the Stripe call and land directly in `cancelled`.

### 7.5 Waitlist

```
Tier sold out → POST /api/v1/events/:id/waitlist { ticket_type_id, quantity }
  └─ entry created status=waiting, position = MAX(position)+1

Inventory freed (cancel or expiry)
  └─ WaitlistPromotionJob → Waitlist::PromotionService
       ├─ FIFO scan by position; skip (without penalty) any entry whose
       │  quantity exceeds remaining freed stock — never partially fill
       ├─ resolve a null ticket_type_id to the tier being freed
       ├─ entry → offered, claim_token = SecureRandom.urlsafe_base64(32)
       ├─ claim_expires_at = now + 24h   (offer holds inventory)
       └─ WaitlistOfferMailer#offer → link to /waitlist/claim/:token

Attendee claims
  └─ POST /api/v1/waitlist/claim/:token
       └─ Waitlist::ClaimService → entry claimed, pending Order created
       └─ normal checkout flow from here

Offer lapses
  └─ WaitlistOfferExpiryJob → entry expired, hold released, next entry promoted
```

---

## 8. QR codes, PDFs, and email

### Code generation

```ruby
# app/models/ticket.rb
ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ' # Crockford base32: no I, L, O, U

def self.generate_code
  loop do
    candidate = "EB-#{Array.new(12) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join}"
    return candidate unless exists?(code: candidate)
  end
end
```

Roughly 2^60 of entropy. The unique index on `code` is the real guarantee; the loop just avoids a retry storm.

### PDF

One PDF per ticket, rendered on demand and never stored (regenerating is cheap and always reflects current event data). Contents: event name, date/time, venue and address, ticket tier, order number, holder email, the QR, and the human-readable code beneath it as a scanner fallback.

Gems: `prawn`, `prawn-qrcode`.

### Browser rendering

`/profile/orders/[id]` renders each ticket's QR client-side with `qrcode.react` from the `code` string in the JSON payload. No image endpoint, no extra round trip. The `code` — not any rendered image — is the canonical artifact.

### Email

`BookingMailer` is superseded by `OrderMailer#confirmation`, reusing the existing SendGrid configuration. One email per order with N PDF attachments. `BookingMailer` is removed once no code references it.

---

## 9. Check-in API

```
GET  /api/v1/tickets/:code          → validate without consuming (organizer preview)
POST /api/v1/tickets/:code/check_in → consume
```

Authorization: the event's `creator` or an `admin`. Enforced by `TicketPolicy`.

| Condition | Response |
|---|---|
| Valid, `issued` | `200` — ticket + holder + event, status now `checked_in` |
| Already `checked_in` | `409` — includes original `checked_in_at` and scanner |
| Ticket `cancelled` | `422` |
| Code not found | `404` |
| Ticket belongs to another event | `422` |
| Caller not organizer/admin | `403` |

Check-in is wrapped in a transaction with a row lock on the ticket, so two simultaneous scans cannot both succeed.

---

## 10. API surface

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/events/:event_id/orders` | Create pending order from a cart |
| `GET` | `/api/v1/orders` | List my orders (paginated via Pagy) |
| `GET` | `/api/v1/orders/:id` | Order detail with bookings and tickets |
| `POST` | `/api/v1/orders/:id/checkout` | Create Stripe Checkout Session |
| `DELETE` | `/api/v1/orders/:id` | Cancel and refund |
| `GET` | `/api/v1/tickets/:code/download` | Ticket PDF |
| `GET` | `/api/v1/tickets/:code` | Organizer validation lookup |
| `POST` | `/api/v1/tickets/:code/check_in` | Organizer check-in |
| `POST` | `/api/v1/events/:event_id/waitlist` | Join waitlist |
| `DELETE` | `/api/v1/waitlist/:id` | Leave waitlist |
| `POST` | `/api/v1/waitlist/claim/:token` | Claim an offer |
| `POST` | `/api/v1/checkout/webhook` | Existing endpoint, extended for orders and refunds |

Legacy `POST /api/v1/events/:event_id/bookings` and `PATCH /api/v1/bookings/:id/cancel` remain until the frontend has fully migrated, then are removed in a follow-up.

### Serializers

New: `OrderSerializer` (embeds bookings), `TicketSerializer` (`code`, `status`, `checked_in_at`), `WaitlistEntrySerializer`. `BookingSerializer` gains `tickets`.

---

## 11. Frontend

All four surfaces, styled with the `ui-ux-pro-max` skill during implementation.

### `/events/[id]` — ticket picker
Per-tier rows with quantity steppers, live per-tier and order subtotals, sold-out badges, disabled steppers at the per-order cap with an inline explanation, remaining-inventory hints when stock is low, and a sticky "Get tickets" summary bar on mobile. Sold-out tiers surface a "Join waitlist" action instead.

### `/profile/orders` and `/profile/orders/[id]`
Replaces today's `/profile/bookings`. List view with Upcoming / Past tabs and status badges. Detail view shows each ticket as a card with its QR, its code, a "Download PDF" button, a "Download all" action, and a Cancel Order button whose enabled state reflects the cutoff.

### `/checkout/success` and `/checkout/cancel`
Success polls `GET /api/v1/orders/:id` until `paid` (with a spinner and a fallback message if the webhook is slow), then renders tickets inline with download links. Cancel explains that the order is held for 15 minutes and offers a "Resume checkout" button.

### Cancel modal
Shows the refund amount, the cutoff deadline in the user's timezone, a reason dropdown, and a typed confirmation. Disabled with an explanation once past the cutoff.

### New frontend dependencies
`qrcode.react` for in-browser QR rendering.

---

## 12. Authorization

| Policy | Rules |
|---|---|
| `OrderPolicy` | `show?`/`cancel?`: owner or admin. `create?`: any authenticated user. `index?` scoped to own orders. |
| `TicketPolicy` | `show?`/`download?`: ticket's buyer or admin. `check_in?`/`validate?`: event creator or admin. |
| `WaitlistEntryPolicy` | `create?`: authenticated. `destroy?`: owner or admin. `claim?`: token-bearer must match `entry.user`. |

The existing `prevent_admin_role_assignment` guard on `User` is untouched.

---

## 13. Error handling

| Failure | Handling |
|---|---|
| Tier sold out during checkout | `422` with per-tier availability so the UI can correct the cart in place |
| Per-order cap exceeded | `422` naming the cap |
| Order expired before payment | `410 Gone`; frontend offers to rebuild the cart |
| Stripe session creation fails | `422`, order stays `pending` and remains retryable until `expires_at` |
| Webhook arrives twice | Idempotent by `stripe_checkout_session_id`; second call is a no-op |
| Webhook never arrives | Order expires normally; a Sentry warning fires if a session was created but never completed |
| Refund API fails | Order stays `paid`, error surfaced, Sentry alert; no partial state is written (transaction rolls back before the status change) |
| PDF render fails | Email still sends with a link to download from the profile page; Sentry captures the failure |
| Duplicate ticket code | Unique index rejects; generator retries |
| Double scan | `409` with the original check-in metadata |

All Stripe interactions are wrapped in `rescue Stripe::StripeError` and reported to Sentry, which is already configured.

---

## 14. Testing

Following the existing Minitest setup.

**Models** — order status transitions; `available_quantity` across pending/paid/expired/cancelled/offered states; ticket code uniqueness and format; cutoff calculation; per-order cap validation.

**Services** — `Orders::CreationService` (happy path, oversell rejection, cap rejection, free-event short circuit, concurrent-buyer serialisation); `Orders::CancellationService` (before/after cutoff, refund issued, inventory released, free order path); `Tickets::IssuanceService` (correct count, idempotency); `Tickets::CheckInService` (each result branch); `Waitlist::PromotionService` (FIFO order, partial fits, offer holds inventory).

**Controllers** — full request specs for every endpoint in §10, including authorization failures and the webhook's idempotency.

**Integration** — end-to-end paid purchase with a stubbed Stripe webhook; end-to-end free purchase; cancel-and-refund round trip; waitlist promotion after a cancellation.

**Frontend** — Jest + React Testing Library (already configured) for the ticket picker's cap and sold-out behaviour, and for the cancel modal's cutoff states.

Stripe is stubbed with `webmock` throughout; no test hits the network.

---

## 15. Rollout

Phased so each step is independently shippable and reversible.

| Phase | Contents |
|---|---|
| **1 — Data foundation** | Migrations, backfill, models, associations, inventory scopes, model tests |
| **2 — Order + payment** | Creation/Checkout/PaymentCompletion services, webhook extension, free-event path, order endpoints |
| **3 — Tickets + QR + PDF** | Issuance service, code generation, PDF renderer, `OrderMailer`, download endpoints |
| **4 — Cancellation** | Cancellation service, cutoff rule, Stripe refunds, refund webhook |
| **5 — Check-in API** | `TicketPolicy`, validation and check-in endpoints, state machine |
| **6 — Frontend** | Ticket picker, orders list/detail, checkout polish, cancel modal |
| **7 — Waitlist** | Tables, promotion/claim services, offer mailer, expiry job, waitlist UI |
| **8 — Cleanup** | Drop superseded Stripe columns on `bookings`, remove legacy booking endpoints and `BookingMailer` |

Phases 1–6 deliver everything originally asked for. Phase 7 is additive and can slip without blocking. Phase 8 only runs once phases 1–6 are verified in production.

---

## 16. Open items

None. All design questions were resolved before this document was written.
