# Events Berlin API Documentation

## Overview

Events Berlin is an Eventbrite clone built with Ruby on Rails, featuring comprehensive event management, ticketing, and booking capabilities.

## Tech Stack

- **Backend**: Ruby on Rails 7.1
- **Database**: PostgreSQL
- **Authentication**: Devise (session-based)
- **Authorization**: Pundit
- **Background Jobs**: Sidekiq
- **File Upload**: Active Storage
- **API**: JSON API with ActiveModel Serializers

## Authentication

Currently using Devise with session-based authentication. For production API usage, consider implementing:
- JWT token authentication (recommended for stateless API)
- API token authentication
- OAuth 2.0

See `SECURITY.md` for detailed authentication setup recommendations.

**CSRF Protection**: API endpoints use `protect_from_forgery with: :null_session` to support both session and token-based authentication. For production, implement proper token-based authentication.

## Models

### User
- Roles: attendee (default), organizer, admin
- Has many events (as creator)
- Has many bookings (as attendee)
- Devise authentication

### Event
- Belongs to creator (User)
- Belongs to category (optional)
- Belongs to venue (optional)
- Has many bookings
- Has many ticket_types
- Has one attached image (Active Storage)
- Fields: name, description, location, date, price, capacity, private

### Category
- Has many events
- Fields: name (unique), description

### Venue
- Has many events
- Fields: name, address, city, capacity

### TicketType
- Belongs to event
- Has many bookings
- Fields: name, price, quantity, description

### Booking
- Belongs to user, event, ticket_type
- Fields: quantity, total_price, status (pending, confirmed, cancelled), payment_status (unpaid, paid, failed, refunded), stripe_checkout_session_id, stripe_payment_intent_id, paid_at
- Auto-calculates total_price based on quantity and ticket_type price

## API Endpoints

### Events
- `GET /api/v1/events` - List all events (with filters)
  - Query params: `category_id`, `location`, `search`, `start_date`, `end_date`, `upcoming`
- `GET /api/v1/events/:id` - Get event details
- `POST /api/v1/events` - Create event (organizer/admin only)
- `PUT /api/v1/events/:id` - Update event (creator/admin only)
- `DELETE /api/v1/events/:id` - Delete event (creator/admin only)

### Bookings
- `GET /api/v1/bookings` - List user's bookings
- `GET /api/v1/bookings/:id` - Get booking details
- `POST /api/v1/events/:id/bookings` - Create booking
- `PUT /api/v1/bookings/:id` - Update booking
- `PATCH /api/v1/bookings/:id/cancel` - Cancel booking

### Checkout (Stripe)
- `POST /api/v1/checkout/sessions` - Create Stripe Checkout session
  - Request body: `{ booking_id: number }`
  - Response: `{ checkout_url: string, session_id: string }`
- `POST /api/v1/checkout/webhook` - Stripe webhook endpoint (no auth required)
  - Handles: `checkout.session.completed`, `payment_intent.succeeded`, `payment_intent.payment_failed`

### Users
- `GET /api/v1/users/profile` - Get current user profile
- `GET /api/v1/users/events` - Get user's created events
- `GET /api/v1/users/bookings` - Get user's bookings

## Authorization

Using Pundit for authorization:
- **Event**: Organizers and admins can create events; only creators and admins can update/delete
- **Booking**: Users can only view and manage their own bookings; admins can view all

## Service Objects

### BookingService
Handles ticket purchase logic:
- Validates ticket availability
- Validates event capacity
- Creates booking
- Integrates with PaymentService

### PaymentService
Stripe payment integration:
- `create_payment_intent` - Create Stripe PaymentIntent for booking
- `process_refund` - Refund a paid booking
- `retrieve_checkout_session` - Get checkout session details

## Background Jobs

### BookingConfirmationJob
Sends confirmation email after successful booking (placeholder for email integration)

## Search & Filtering

Event scopes available:
- `upcoming` - Events from today onwards
- `past` - Past events
- `by_category(category_id)` - Filter by category
- `by_location(location)` - Search by location
- `by_date_range(start_date, end_date)` - Filter by date range
- `search_by_name(query)` - Search by event name

## Database Indexes

Performance indexes added for:
- Categories: name (unique)
- Venues: [name, city]
- TicketTypes: [event_id, name]
- Bookings: [user_id, event_id], status
- Users: role

## Setup

1. Install dependencies: `bundle install`
2. Setup database: `rails db:create db:migrate`
3. Configure Stripe:
   - Get API keys from https://dashboard.stripe.com/apikeys
   - Set environment variables:
     ```bash
     export STRIPE_SECRET_KEY=sk_test_...
     export STRIPE_WEBHOOK_SECRET=whsec_...
     export FRONTEND_URL=http://localhost:3001
     ```
   - Or add to Rails credentials: `EDITOR=vim rails credentials:edit`
4. Start server: `rails server`
5. Start Sidekiq (optional): `bundle exec sidekiq`
6. For Stripe webhooks in local development, use Stripe CLI:
   ```bash
   stripe listen --forward-to localhost:3000/api/v1/checkout/webhook
   ```

## Testing

Run tests with: `rails test`

Tests included for:
- Models (validations, associations)
- Controllers (API endpoints)
- Policies (authorization rules)

## Orders

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/events/:event_id/orders` | Bearer | Create a pending order from a cart of `{ticket_type_id, quantity}` items. Free events return a `paid` order immediately. |
| `GET` | `/api/v1/orders` | Bearer | List the caller's orders, paginated. |
| `GET` | `/api/v1/orders/:id` | Bearer | Order detail including bookings and tickets. |
| `POST` | `/api/v1/orders/:id/checkout` | Bearer | Create a Stripe Checkout Session; returns `checkout_url`. |
| `DELETE` | `/api/v1/orders/:id` | Bearer | Cancel and refund. Refused past the event's cancellation cutoff. |

### Order states

`pending` → `paid` | `expired` | `cancelled` | `refunded`

A pending order holds inventory for 15 minutes. `OrderExpiryJob` sweeps lapsed orders every minute.

### Error codes

Creation (`POST /api/v1/events/:event_id/orders`): `invalid_items`, `event_past`, `cap_exceeded`, `sold_out`

Checkout (`POST /api/v1/orders/:id/checkout`): `not_payable`, `payment_in_progress`, `amount_mismatch`, `stripe_error`

Payment completion (webhook): `not_completable`

Cancellation (`DELETE /api/v1/orders/:id`): `not_cancellable`, `past_cutoff`, `refund_failed`

## Tickets

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/tickets/:code` | Organiser | Validate a ticket without consuming it. |
| `GET` | `/api/v1/tickets/:code/download` | Holder | Download the ticket as a PDF with an embedded QR code. |
| `POST` | `/api/v1/tickets/:code/check_in` | Organiser | Consume the ticket at the door. Returns `409` if already used. |

Check-in error codes: `cancelled`, `already_checked_in`, `event_not_started`.

Ticket codes are `EB-` followed by 12 Crockford base32 characters, e.g. `EB-A7X9K2M4P8Q3`.
The QR encodes the bare code, so any scanner can read it offline.
