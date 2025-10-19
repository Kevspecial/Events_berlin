# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Clear old data
puts 'Clearing existing data...'
Booking.destroy_all
TicketType.destroy_all
Attending.destroy_all
Invite.destroy_all
Event.destroy_all
Venue.destroy_all
Category.destroy_all
User.destroy_all

# Create categories
puts 'Creating categories...'
music = Category.create!(name: 'Music', description: 'Concerts, festivals, and live music events')
tech = Category.create!(name: 'Technology', description: 'Tech meetups, conferences, and workshops')
sports = Category.create!(name: 'Sports', description: 'Sports events and fitness activities')
food = Category.create!(name: 'Food & Drink', description: 'Food festivals, wine tastings, and culinary events')
arts = Category.create!(name: 'Arts & Culture', description: 'Art exhibitions, theater, and cultural events')

# Create venues
puts 'Creating venues...'
arena = Venue.create!(
  name: 'Berlin Arena',
  address: 'Eichenstraße 4',
  city: 'Berlin',
  capacity: 5000
)

conference_center = Venue.create!(
  name: 'Tech Conference Center',
  address: 'Alexanderplatz 7',
  city: 'Berlin',
  capacity: 500
)

art_gallery = Venue.create!(
  name: 'Modern Art Gallery',
  address: 'Friedrichstraße 23',
  city: 'Berlin',
  capacity: 200
)

# Create users
puts 'Creating users...'
admin = User.create!(
  email: 'admin@events-berlin.com',
  password: 'password',
  role: :admin
)

organizer1 = User.create!(
  email: 'organizer@events-berlin.com',
  password: 'password',
  role: :organizer
)

organizer2 = User.create!(
  email: 'organizer2@events-berlin.com',
  password: 'password',
  role: :organizer
)

alice = User.create!(email: 'alice@example.com', password: 'password', role: :attendee)
bob = User.create!(email: 'bob@example.com', password: 'password', role: :attendee)
carol = User.create!(email: 'carol@example.com', password: 'password', role: :attendee)

# Create events
puts 'Creating events...'

# Music event
music_event = organizer1.created_events.create!(
  name: 'Berlin Summer Music Festival',
  description: 'Join us for an amazing outdoor music festival featuring local and international artists',
  location: 'Tempelhofer Feld',
  date: 2.weeks.from_now,
  private: false,
  category: music,
  venue: arena,
  price: 45.00,
  capacity: 5000
)

# Create ticket types for music event
music_event.ticket_types.create!([
  { name: 'General Admission', price: 45.00, quantity: 4000, description: 'Standard entry' },
  { name: 'VIP Pass', price: 120.00, quantity: 500, description: 'VIP area access with complimentary drinks' },
  { name: 'Early Bird', price: 35.00, quantity: 500, description: 'Limited early bird special' }
])

# Tech event
tech_event = organizer2.created_events.create!(
  name: 'Berlin Tech Summit 2025',
  description: 'Annual technology conference featuring industry leaders and innovators',
  location: 'Alexanderplatz',
  date: 1.month.from_now,
  private: false,
  category: tech,
  venue: conference_center,
  price: 0,
  capacity: 500
)

# Create ticket types for tech event
tech_event.ticket_types.create!([
  { name: 'Free Admission', price: 0, quantity: 400, description: 'Free entry for all attendees' },
  { name: 'Premium Pass', price: 99.00, quantity: 100, description: 'Access to premium workshops and networking' }
])

# Arts event
arts_event = organizer1.created_events.create!(
  name: 'Contemporary Art Exhibition',
  description: 'Explore modern art from emerging Berlin artists',
  location: 'Friedrichstraße',
  date: 3.days.from_now,
  private: false,
  category: arts,
  venue: art_gallery,
  price: 15.00,
  capacity: 200
)

arts_event.ticket_types.create!([
  { name: 'Standard Entry', price: 15.00, quantity: 180, description: 'Gallery admission' },
  { name: 'Guided Tour', price: 30.00, quantity: 20, description: 'Guided tour with the curator' }
])

# Private event
private_event = organizer2.created_events.create!(
  name: 'Founders Networking Dinner',
  description: 'Exclusive networking dinner for startup founders',
  location: 'Private Location',
  date: 10.days.from_now,
  private: true,
  category: tech,
  price: 50.00,
  capacity: 30
)

private_event.ticket_types.create!([
  { name: 'Dinner Ticket', price: 50.00, quantity: 30, description: 'Includes 3-course dinner' }
])

# Create some bookings
puts 'Creating bookings...'
Booking.create!(
  user: alice,
  event: music_event,
  ticket_type: music_event.ticket_types.find_by(name: 'General Admission'),
  quantity: 2,
  status: 'confirmed'
)

Booking.create!(
  user: bob,
  event: tech_event,
  ticket_type: tech_event.ticket_types.find_by(name: 'Free Admission'),
  quantity: 1,
  status: 'confirmed'
)

Booking.create!(
  user: carol,
  event: arts_event,
  ticket_type: arts_event.ticket_types.find_by(name: 'Guided Tour'),
  quantity: 1,
  status: 'pending'
)

# Create attendings (for backward compatibility)
puts 'Creating event attendees...'
music_event.attendees << alice
music_event.attendees << bob
tech_event.attendees << carol

# Create invites
puts 'Creating invites...'
Invite.create!(event: private_event, inviter: organizer2, invitee: alice)
Invite.create!(event: private_event, inviter: organizer2, invitee: bob)

puts "\n=== Seed Complete ==="
puts "Created #{User.count} users"
puts "Created #{Category.count} categories"
puts "Created #{Venue.count} venues"
puts "Created #{Event.count} events"
puts "Created #{TicketType.count} ticket types"
puts "Created #{Booking.count} bookings"
puts "Created #{Attending.count} attendings"
puts "Created #{Invite.count} invites"
puts "\nSample credentials:"
puts "Admin: admin@events-berlin.com / password"
puts "Organizer: organizer@events-berlin.com / password"
puts "Attendee: alice@example.com / password"
AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password') if Rails.env.development?