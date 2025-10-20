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

# Base venues used by initial events
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

# Additional venues for richer dataset
stadium = Venue.create!(
  name: 'Olympiastadion Berlin',
  address: 'Olympischer Platz 3',
  city: 'Berlin',
  capacity: 74_000
)

club = Venue.create!(
  name: 'Berghain',
  address: 'Am Wriezener Bahnhof',
  city: 'Berlin',
  capacity: 1500
)

Venue.create!(
  name: 'Restaurant Borchardt',
  address: 'Französische Straße 47',
  city: 'Berlin',
  capacity: 120
)

park = Venue.create!(
  name: 'Tiergarten Park',
  address: 'Strasse des 17. Juni',
  city: 'Berlin',
  capacity: 10_000
)

startup_hub = Venue.create!(
  name: 'Factory Berlin',
  address: 'Rheinsberger Str. 76/77',
  city: 'Berlin',
  capacity: 300
)

## Additional events/users/bookings are moved to the end so required variables are defined first

# Create users
puts 'Creating users...'
User.create!(
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
                                   { name: 'General Admission', price: 45.00, quantity: 4000,
                                     description: 'Standard entry' },
                                   { name: 'VIP Pass', price: 120.00, quantity: 500,
                                     description: 'VIP area access with complimentary drinks' },
                                   { name: 'Early Bird', price: 35.00, quantity: 500,
                                     description: 'Limited early bird special' }
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
                                  { name: 'Free Admission', price: 0, quantity: 400,
                                    description: 'Free entry for all attendees' },
                                  { name: 'Premium Pass', price: 99.00, quantity: 100,
                                    description: 'Access to premium workshops and networking' }
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
                                  { name: 'Standard Entry', price: 15.00, quantity: 180,
                                    description: 'Gallery admission' },
                                  { name: 'Guided Tour', price: 30.00, quantity: 20,
                                    description: 'Guided tour with the curator' }
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
                                     { name: 'Dinner Ticket', price: 50.00, quantity: 30,
                                       description: 'Includes 3-course dinner' }
                                   ])

# Create some bookings
puts 'Creating bookings...'
Booking.create!(
  user: alice,
  event: music_event,
  ticket_type: music_event.ticket_types.find_by(name: 'General Admission'),
  quantity: 2,
  total_price: 2 * music_event.ticket_types.find_by(name: 'General Admission').price,
  status: 'confirmed'
)

Booking.create!(
  user: bob,
  event: tech_event,
  ticket_type: tech_event.ticket_types.find_by(name: 'Free Admission'),
  quantity: 1,
  total_price: 1 * tech_event.ticket_types.find_by(name: 'Free Admission').price,
  status: 'confirmed'
)

Booking.create!(
  user: carol,
  event: arts_event,
  ticket_type: arts_event.ticket_types.find_by(name: 'Guided Tour'),
  quantity: 1,
  total_price: 1 * arts_event.ticket_types.find_by(name: 'Guided Tour').price,
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
puts 'Admin: admin@events-berlin.com / password'
puts 'Organizer: organizer@events-berlin.com / password'
puts 'Attendee: alice@example.com / password'
if Rails.env.development?
  AdminUser.create!(email: 'admin@example.com', password: 'password',
                    password_confirmation: 'password')
end

# --- Additional dataset for richer testing ---
puts '\nCreating additional sample dataset...'

# Sports event
sports_event = organizer1.created_events.create!(
  name: 'Berlin Marathon 2025',
  description: 'Run the iconic Berlin Marathon through the heart of the city',
  location: 'Brandenburg Gate Start',
  date: 2.months.from_now,
  private: false,
  category: sports,
  venue: stadium,
  price: 120.00,
  capacity: 40_000
)

sports_event.ticket_types.create!([
                                    { name: 'Full Marathon', price: 120.00, quantity: 35_000,
                                      description: '42.195km race' },
                                    { name: 'Half Marathon', price: 80.00, quantity: 5000, description: '21.1km race' }
                                  ])

# Food event
food_event = organizer2.created_events.create!(
  name: 'Berlin Food Festival',
  description: 'Taste authentic cuisine from around the world at this annual food festival',
  location: 'Alexanderplatz',
  date: 3.weeks.from_now,
  private: false,
  category: food,
  venue: park,
  price: 25.00,
  capacity: 5000
)

food_event.ticket_types.create!([
                                  { name: 'Day Pass', price: 25.00, quantity: 4000,
                                    description: 'Full day access to all food stalls' },
                                  { name: 'VIP Experience', price: 75.00, quantity: 200,
                                    description: 'VIP area with chef meet & greets' }
                                ])

# Club event
club_event = organizer1.created_events.create!(
  name: 'Techno Night at Berghain',
  description: 'World-renowned techno club night featuring international DJs',
  location: 'Kreuzberg',
  date: 1.week.from_now,
  private: false,
  category: music,
  venue: club,
  price: 20.00,
  capacity: 1500
)

club_event.ticket_types.create!([
                                  { name: 'Standard Entry', price: 20.00, quantity: 1200,
                                    description: 'Regular entry' },
                                  { name: 'Table Reservation', price: 100.00, quantity: 50,
                                    description: 'Reserved table with bottle service' }
                                ])

# Business networking event
networking_event = organizer2.created_events.create!(
  name: 'Berlin Startup Pitch Night',
  description: 'Watch innovative startups pitch to investors and network with entrepreneurs',
  location: 'Mitte',
  date: 2.weeks.from_now,
  private: false,
  category: tech,
  venue: startup_hub,
  price: 15.00,
  capacity: 200
)

networking_event.ticket_types.create!([
                                        { name: 'Attendee', price: 15.00, quantity: 150,
                                          description: 'Access to pitches and networking' },
                                        { name: 'VIP Investor Pass', price: 50.00, quantity: 50,
                                          description: 'Meet the startups privately' }
                                      ])

# Cultural event
cultural_event = organizer1.created_events.create!(
  name: 'Berlin Biennale Opening',
  description: 'Opening night of the prestigious Berlin Biennale contemporary art exhibition',
  location: 'Potsdamer Straße',
  date: 4.days.from_now,
  private: false,
  category: arts,
  venue: art_gallery,
  price: 35.00,
  capacity: 300
)

cultural_event.ticket_types.create!([
                                      { name: 'Opening Night', price: 35.00, quantity: 250,
                                        description: 'Opening night admission' },
                                      { name: 'VIP Preview', price: 100.00, quantity: 50,
                                        description: 'Private preview before opening' }
                                    ])

# Additional users
puts 'Creating additional users...'
extra_users = []
10.times do |i|
  extra_users << User.create!(
    email: "user#{i + 1}@example.com",
    password: 'password',
    role: :attendee
  )
end

# Extra bookings
puts 'Creating additional bookings...'
all_events = [music_event, tech_event, arts_event, sports_event, food_event, club_event, networking_event,
              cultural_event]

extra_users.each do |user|
  rand(1..3).times do
    ev = all_events.sample
    tt = ev.ticket_types.sample
    next unless tt.available_quantity.positive?

    qty = [1, 2, 3].sample
    qty = [qty, tt.available_quantity].min

    Booking.create!(user: user, event: ev, ticket_type: tt, quantity: qty,
                    total_price: qty * tt.price,
                    status: %w[confirmed pending cancelled].sample)
  end
end
