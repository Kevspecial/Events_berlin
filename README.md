# Events berlin

A curated platform to discover and manage events happening in Berlin – built with modern web tools.

## Overview

Events Berlin is an Eventbrite clone featuring comprehensive event management, ticketing, and booking capabilities. Built with Ruby on Rails 7.1 and PostgreSQL.

## Features

- 🎫 **Event Management**: Create, update, and manage events with categories and venues
- 👥 **User Roles**: Attendee, Organizer, and Admin roles with proper authorization
- 🎟️ **Ticketing System**: Multiple ticket types per event with quantity management
- 💳 **Booking System**: Complete booking flow with status tracking
- 🔍 **Search & Filtering**: Filter events by category, location, date range, and search by name
- 📸 **Image Uploads**: Event images with Active Storage
- 🔐 **Authorization**: Pundit-based authorization for secure access control
- 📊 **RESTful API**: JSON API with ActiveModel Serializers
- ⚡ **Background Jobs**: Sidekiq for asynchronous processing

## Tech Stack

- **Backend**: Ruby on Rails 7.1
- **Database**: PostgreSQL
- **Authentication**: Devise
- **Authorization**: Pundit
- **Background Jobs**: Sidekiq
- **File Upload**: Active Storage
- **Linting**: RuboCop
- **Security**: Brakeman

## Getting Started

### Prerequisites

- Ruby 3.2.3
- PostgreSQL
- Redis (for Sidekiq)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Kevspecial/Events_berlin.git
cd Events_berlin
```

2. Install dependencies:
```bash
bundle install
```

3. Setup database:
```bash
rails db:create
rails db:migrate
rails db:seed
```

4. Start the server:
```bash
rails server
```

5. (Optional) Start Sidekiq for background jobs:
```bash
bundle exec sidekiq
```

## API Documentation

See [API_DOCUMENTATION.md](API_DOCUMENTATION.md) for detailed API endpoint documentation.

## Security

See [SECURITY.md](SECURITY.md) for security best practices and authentication setup recommendations.

## Testing

Run the test suite:
```bash
rails test
```

Run linter:
```bash
bin/rubocop
```

Run security scan:
```bash
bin/brakeman
```

## Database Schema

### Core Models

- **User**: Authentication and user management with roles (attendee, organizer, admin)
- **Event**: Event details with category, venue, pricing, and capacity
- **Category**: Event categorization
- **Venue**: Event locations
- **TicketType**: Different ticket tiers for events
- **Booking**: Ticket purchases with status tracking

### Relationships

- User has many Events (as creator/organizer)
- User has many Bookings (as attendee)
- Event belongs to Category and Venue
- Event has many TicketTypes and Bookings
- Booking belongs to User, Event, and TicketType

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source and available under the MIT License.
