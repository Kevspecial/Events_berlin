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
- Fields: quantity, total_price, status (pending, confirmed, cancelled)
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
Placeholder for Stripe integration:
- Process payments
- Update booking status

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
3. Start server: `rails server`
4. Start Sidekiq (optional): `bundle exec sidekiq`

## Testing

Run tests with: `rails test`

Tests included for:
- Models (validations, associations)
- Controllers (API endpoints)
- Policies (authorization rules)
