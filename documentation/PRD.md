Events Berlin — Product Requirements Document (Production v1.0)

Product Name: Events Berlin
Stage: Public MVP → Production Launch
Document Owner: Product
Target Launch: Q1 Production Release

1. Product Vision & Positioning
Vision

Events Berlin is a local-first event discovery and booking platform optimized for Berlin’s cultural, professional, and community-driven events. Unlike global marketplaces, Events Berlin prioritizes speed, trust, and locality over scale.

Positioning Statement

For people in Berlin who want to discover and attend events without friction, Events Berlin offers a fast, curated, and reliable booking experience built specifically for the local ecosystem.

2. Business Objectives
Primary Objectives

Enable attendees to discover and book events in under 3 minutes

Ensure zero overbooking incidents in production

Provide admins full operational control with minimal engineering intervention

Secondary Objectives

Prepare platform foundations for organizer self-service

Establish technical credibility for future partnerships and monetization

3. In-Scope vs Out-of-Scope (Launch Guardrails)
In Scope (v1)

Public event discovery

Authenticated booking

Admin-managed events and ticketing

Free events and/or fixed-price paid events (single currency)

Explicitly Out of Scope

Seat maps / reserved seating

Dynamic pricing

Multi-day passes

External marketplace integrations

Native mobile apps

4. User Personas
Attendee

Discovers events

Books tickets

Manages personal bookings

Organizer (Admin-Managed)

Events are created and managed by admins on behalf of organizers (v1)

Organizer self-service UI deferred to v2

Admin

Full control over users, events, bookings, refunds, disputes

Operates exclusively via ActiveAdmin

5. Core User Flows
Attendee Flow

Browse events (unauthenticated)

View event detail

Sign up / log in

Book ticket

Receive booking confirmation

Admin Flow

Create/manage events

Define ticket types and capacity

Monitor bookings

Cancel bookings / events if required

6. Booking & Inventory Model (Critical)
Booking States

pending — booking initiated

confirmed — booking completed

cancelled — user or admin cancelled

expired — abandoned before completion

Inventory Rules

Ticket availability decremented atomically

No booking may be confirmed if capacity < requested quantity

Database-level constraints enforce capacity integrity

7. Authentication & Authorization
Public Users

User model with role = attendee by default

Role escalation via public API is forbidden

Admin Users

Separate AdminUser model

Access only via /admin

Created via seeds or Rails console

Session Management

Secure, HTTP-only cookies in production

Session invalidation on logout and password change

8. API Requirements (Stable v1 Contract)
Authentication

POST /api/v1/signup

POST /api/v1/login

DELETE /api/v1/logout

Events

GET /api/v1/events

GET /api/v1/events/:id

Bookings

POST /api/v1/events/:event_id/bookings

GET /api/v1/bookings

DELETE /api/v1/bookings/:id

All authenticated endpoints require a valid session.

9. Security & Abuse Prevention

Rate limiting on auth and booking endpoints

CSRF protection enabled for session-based requests

CORS restricted to approved frontend origins

Admin actions audited (create/update/delete)

10. UX & Performance Requirements

Responsive across mobile and desktop

Deterministic SSR output (hydration safe)

Event pages load < 2s on 3G

Booking feedback in < 500ms post-submission

11. Non-Functional Requirements

Availability: 99.5%

Scalability: Read-heavy optimization on events index

Observability: Error logging, request tracing, booking failure alerts

12. Success Metrics (Production-Grade)

Marketplace Health

Events published per week

Tickets booked per event

Booking success rate

User Experience

Time-to-book (median)

Booking failure rate

Repeat bookings per user

Operations

Admin intervention rate per booking

Overbooking incidents (target: zero)

13. Production Readiness Checklist

HTTPS enforced

Secure cookies enabled

Seeds removed or rotated

Backups scheduled

CI/CD pipeline active

Error monitoring live

14. Risks & Mitigations
Risk	Mitigation
Overbooking	DB constraints + atomic updates
Abuse	Rate limiting + monitoring
Admin errors	Auditing + confirmation prompts
Traffic spikes	Caching + pagination

15. Milestones

MVP Complete: Core browsing + booking

Production Hardening: Security, monitoring, ops

Post-Launch: Organizer self-service, payments, email workflows (See <attachments> above for file contents. You may not need to search or read the file again.)
