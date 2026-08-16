# Ticketing Backend Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete backend for multi-tier ticket purchase, per-ticket QR codes delivered as PDFs, order cancellation with Stripe refunds, and an API-only check-in flow.

**Architecture:** Introduce an `Order` layer above the existing `Booking` table and a `Ticket` layer below it, so `Order → Booking → Ticket` maps to payment → line item → scanable unit. `Booking` keeps its table, ActiveAdmin resource, policy, and serializer; only its meaning narrows. Inventory is held by a database scope rather than a lock service, and every state transition lives in a single-purpose service object following the existing `BookingService` convention.

**Tech Stack:** Ruby 3.2.2, Rails 7.1.5, PostgreSQL, Minitest with fixtures, Pundit, ActiveModel Serializers, Sidekiq 7, Stripe 10, Prawn (PDF), WebMock (HTTP stubbing).

**Source spec:** `docs/superpowers/specs/2026-08-15-ticketing-qr-cancellation-design.md`

## Global Constraints

- Every Ruby file starts with `# frozen_string_literal: true`.
- Single-quoted strings unless interpolating — the repo runs RuboCop with `bin/rubocop`.
- Service objects live in `app/services/`, namespaced in subdirectories (`app/services/orders/`, `app/services/tickets/`), and expose a single `#call` returning a Hash with a `:success` key — matching the existing `BookingService`.
- Failure hashes carry `{ success: false, error: String, code: Symbol }`. Success hashes carry `{ success: true, <resource>: obj }`.
- Controllers under `Api::V1` inherit from `Api::V1::BaseController`, which already rescues `ActiveRecord::RecordNotFound` → 404, `ActiveRecord::RecordInvalid` → 422, and `Pundit::NotAuthorizedError` → 403. Do not re-rescue these.
- Tests are Minitest, `require 'test_helper'`, using fixtures. Match the assertion style in `test/services/booking_service_test.rb`.
- No test may make a real network call. Stripe is stubbed with WebMock throughout.
- Ticket code format is exactly `EB-` followed by 12 Crockford base32 characters from the alphabet `0123456789ABCDEFGHJKMNPQRSTVWXYZ` (no I, L, O, U).
- Order hold duration is exactly 15 minutes. Default cancel cutoff is 24 hours. Default max tickets per order is 10.
- Run `bin/rubocop` before every commit; fix offences before committing. **Migrations are exempt from `Metrics/AbcSize`, `Metrics/MethodLength`, and `Metrics/BlockLength`** — `.rubocop.yml` carries these exclusions, matching the pre-existing `BlockLength` precedent. Prescribed migration code is longer than 15 lines by nature; do not restructure a migration to satisfy a metrics cop, and do not relax any other cop without asking.

---

## File Structure

**New models** — `app/models/order.rb`, `app/models/ticket.rb`
**Modified models** — `app/models/booking.rb`, `app/models/ticket_type.rb`, `app/models/event.rb`, `app/models/user.rb`

**New services**
- `app/services/orders/creation_service.rb` — cart → pending order
- `app/services/orders/checkout_service.rb` — order → Stripe session
- `app/services/orders/payment_completion_service.rb` — webhook → paid + issuance
- `app/services/orders/cancellation_service.rb` — cancel + refund
- `app/services/tickets/issuance_service.rb` — paid order → ticket rows
- `app/services/tickets/pdf_renderer.rb` — ticket → PDF bytes
- `app/services/tickets/check_in_service.rb` — scan state machine

**New controllers** — `app/controllers/api/v1/orders_controller.rb`, `app/controllers/api/v1/tickets_controller.rb`
**Modified controller** — `app/controllers/api/v1/checkout_controller.rb` (webhook extension)

**New policies** — `app/policies/order_policy.rb`, `app/policies/ticket_policy.rb`
**New serializers** — `app/serializers/order_serializer.rb`, `app/serializers/ticket_serializer.rb`
**Modified serializer** — `app/serializers/booking_serializer.rb`

**New jobs** — `app/jobs/order_expiry_job.rb`, `app/jobs/order_confirmation_job.rb`
**New mailer** — `app/mailers/order_mailer.rb` + views
**New admin** — `app/admin/orders.rb`, `app/admin/tickets.rb`

Each service owns exactly one state transition, so a reviewer can accept or reject them independently.

---

### Task 1: Orders table and Order model

**Files:**
- Create: `db/migrate/20260815120000_create_orders.rb`
- Create: `app/models/order.rb`
- Create: `test/fixtures/orders.yml`
- Test: `test/models/order_test.rb`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: `Order` with `STATUSES`, `PAYMENT_STATUSES`, `HOLD_DURATION`, instance predicates `#pending?`, `#paid?`, `#cancelled?`, `#expired?`, `#refunded?`, `#free?`, and scope `Order.holding_inventory`

- [ ] **Step 1: Write the migration**

Create `db/migrate/20260815120000_create_orders.rb`:

```ruby
# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.string :currency, null: false, default: 'eur', limit: 3
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.string :payment_status, null: false, default: 'unpaid'
      t.datetime :expires_at, null: false
      t.datetime :paid_at
      t.datetime :cancelled_at
      t.datetime :refunded_at
      t.string :refund_reason

      t.timestamps
    end

    add_index :orders, :status
    add_index :orders, :expires_at
    add_index :orders, :stripe_checkout_session_id, unique: true
    add_index :orders, :stripe_payment_intent_id, unique: true
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== 20260815120000 CreateOrders: migrated` with no errors. `db/schema.rb` gains an `orders` table.

- [ ] **Step 3: Write the failing test**

Create `test/models/order_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:one)
  end

  def build_order(attrs = {})
    Order.new({
      user: @user,
      event: @event,
      total_amount: 59.98,
      expires_at: 15.minutes.from_now
    }.merge(attrs))
  end

  test 'is valid with required attributes' do
    assert build_order.valid?
  end

  test 'defaults to pending and unpaid' do
    order = build_order
    order.save!
    assert_equal 'pending', order.status
    assert_equal 'unpaid', order.payment_status
    assert_equal 'eur', order.currency
  end

  test 'rejects an unknown status' do
    order = build_order(status: 'banana')
    assert_not order.valid?
    assert_includes order.errors[:status], 'is not included in the list'
  end

  test 'rejects a negative total amount' do
    order = build_order(total_amount: -1)
    assert_not order.valid?
  end

  test 'status predicates reflect the status column' do
    assert build_order(status: 'pending').pending?
    assert build_order(status: 'paid').paid?
    assert build_order(status: 'cancelled').cancelled?
    assert build_order(status: 'expired').expired?
    assert build_order(status: 'refunded').refunded?
  end

  test 'free? is true only when total amount is zero' do
    assert build_order(total_amount: 0).free?
    assert_not build_order(total_amount: 0.01).free?
  end

  test 'holding_inventory includes paid orders' do
    order = build_order(status: 'paid')
    order.save!
    assert_includes Order.holding_inventory, order
  end

  test 'holding_inventory includes unexpired pending orders' do
    order = build_order(status: 'pending', expires_at: 5.minutes.from_now)
    order.save!
    assert_includes Order.holding_inventory, order
  end

  test 'holding_inventory excludes expired pending orders' do
    order = build_order(status: 'pending', expires_at: 5.minutes.ago)
    order.save!
    assert_not_includes Order.holding_inventory, order
  end

  test 'holding_inventory excludes cancelled and expired orders' do
    cancelled = build_order(status: 'cancelled')
    cancelled.save!
    expired = build_order(status: 'expired')
    expired.save!

    assert_not_includes Order.holding_inventory, cancelled
    assert_not_includes Order.holding_inventory, expired
  end

  test 'default_expiry is fifteen minutes out' do
    freeze_time do
      assert_in_delta 15.minutes.from_now.to_i, Order.default_expiry.to_i, 1
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/models/order_test.rb`
Expected: FAIL — `NameError: uninitialized constant Order`

- [ ] **Step 5: Write the Order model**

Create `app/models/order.rb`:

```ruby
# frozen_string_literal: true

class Order < ApplicationRecord
  STATUSES = %w[pending paid expired cancelled refunded].freeze
  PAYMENT_STATUSES = %w[unpaid paid refunded failed].freeze
  HOLD_DURATION = 15.minutes

  belongs_to :user
  belongs_to :event
  has_many :bookings, dependent: :destroy
  has_many :tickets, through: :bookings

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payment_status, presence: true, inclusion: { in: PAYMENT_STATUSES }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :expires_at, presence: true

  # An order holds inventory while it is paid, or pending and not yet lapsed.
  scope :holding_inventory, lambda {
    where(status: 'paid').or(where(status: 'pending').where(expires_at: Time.current..))
  }
  scope :sweepable, -> { where(status: 'pending').where(expires_at: ...Time.current) }

  def self.default_expiry
    HOLD_DURATION.from_now
  end

  STATUSES.each do |state|
    define_method(:"#{state}?") { status == state }
  end

  def free?
    total_amount.to_d.zero?
  end

  def reference
    format('ORD-%06d', id)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at expires_at id paid_at payment_status status total_amount updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[bookings event tickets user]
  end
end
```

- [ ] **Step 6: Create the orders fixture**

Create `test/fixtures/orders.yml`:

```yaml
# Read about fixtures at https://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

paid_one:
  user: one
  event: one
  status: paid
  payment_status: paid
  total_amount: 59.98
  currency: eur
  stripe_payment_intent_id: pi_test_paid_one
  expires_at: <%= 15.minutes.from_now.to_fs(:db) %>
  paid_at: <%= 1.hour.ago.to_fs(:db) %>

pending_two:
  user: two
  event: one
  status: pending
  payment_status: unpaid
  total_amount: 99.99
  currency: eur
  expires_at: <%= 15.minutes.from_now.to_fs(:db) %>
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bin/rails test test/models/order_test.rb`
Expected: PASS — 11 runs, 0 failures, 0 errors

- [ ] **Step 8: Lint and commit**

```bash
bin/rubocop app/models/order.rb test/models/order_test.rb db/migrate/20260815120000_create_orders.rb
git add db/migrate/20260815120000_create_orders.rb db/schema.rb app/models/order.rb test/models/order_test.rb test/fixtures/orders.yml
git commit -m "feat(orders): add Order model with inventory-holding scope"
```

---

### Task 2: Link bookings to orders with a backfill

**Files:**
- Create: `db/migrate/20260815120100_add_order_to_bookings.rb`
- Modify: `app/models/booking.rb`
- Modify: `test/fixtures/bookings.yml`
- Test: `test/models/booking_test.rb`

**Interfaces:**
- Consumes: `Order` from Task 1
- Produces: `Booking#order` association, `Booking.holding_inventory` scope

- [ ] **Step 1: Write the migration with backfill**

Create `db/migrate/20260815120100_add_order_to_bookings.rb`:

```ruby
# frozen_string_literal: true

class AddOrderToBookings < ActiveRecord::Migration[7.1]
  def up
    add_reference :bookings, :order, foreign_key: true, null: true, index: true

    # Wrap every pre-existing booking in a single-line shim order so no
    # historical row is lost. Uses raw SQL so it never depends on model code.
    execute <<~SQL.squish
      INSERT INTO orders (
        user_id, event_id, status, total_amount, currency,
        stripe_checkout_session_id, stripe_payment_intent_id, payment_status,
        expires_at, paid_at, created_at, updated_at
      )
      SELECT
        b.user_id,
        b.event_id,
        CASE
          WHEN b.status = 'cancelled' THEN 'cancelled'
          WHEN b.payment_status = 'paid' THEN 'paid'
          ELSE 'pending'
        END,
        b.total_price,
        'eur',
        b.stripe_checkout_session_id,
        b.stripe_payment_intent_id,
        COALESCE(b.payment_status, 'unpaid'),
        b.created_at + INTERVAL '15 minutes',
        b.paid_at,
        b.created_at,
        b.updated_at
      FROM bookings b
      WHERE b.order_id IS NULL
    SQL

    # Pair each booking with the order just created for it. Orders created by
    # this migration match on user, event, and creation timestamp.
    execute <<~SQL.squish
      UPDATE bookings b
      SET order_id = o.id
      FROM orders o
      WHERE b.order_id IS NULL
        AND o.user_id = b.user_id
        AND o.event_id = b.event_id
        AND o.created_at = b.created_at
    SQL

    change_column_null :bookings, :order_id, false
  end

  def down
    remove_reference :bookings, :order, foreign_key: true
    execute 'DELETE FROM orders'
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== 20260815120100 AddOrderToBookings: migrated`. Verify the backfill with:

```bash
bin/rails runner 'puts "bookings=#{Booking.count} orders=#{Order.count} orphans=#{Booking.where(order_id: nil).count}"'
```

Expected: `orphans=0`

- [ ] **Step 3: Write the failing test**

Create `test/models/booking_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class BookingTest < ActiveSupport::TestCase
  test 'belongs to an order' do
    assert_equal orders(:paid_one), bookings(:one).order
  end

  test 'requires an order' do
    booking = Booking.new(
      user: users(:one), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 1, status: 'pending'
    )
    assert_not booking.valid?
    assert_includes booking.errors[:order], 'must exist'
  end

  test 'holding_inventory includes bookings on paid orders' do
    assert_includes Booking.holding_inventory, bookings(:one)
  end

  test 'holding_inventory excludes bookings whose order lapsed' do
    orders(:pending_two).update!(expires_at: 5.minutes.ago)
    assert_not_includes Booking.holding_inventory, bookings(:two)
  end

  test 'calculates total price from ticket type and quantity' do
    booking = Booking.create!(
      order: orders(:paid_one), user: users(:one), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 3, status: 'pending'
    )
    assert_equal ticket_types(:one).price * 3, booking.total_price
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/models/booking_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'order'` and `undefined method 'holding_inventory'`

- [ ] **Step 5: Update the Booking model**

In `app/models/booking.rb`, add the association directly beneath the existing `belongs_to :ticket_type` line:

```ruby
  belongs_to :order
```

And add this scope immediately after the existing `scope :paid` line:

```ruby
  scope :holding_inventory, -> { joins(:order).merge(Order.holding_inventory) }
```

- [ ] **Step 6: Update the bookings fixture**

Replace `test/fixtures/bookings.yml` with:

```yaml
# Read about fixtures at https://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

one:
  order: paid_one
  user: one
  event: one
  ticket_type: one
  quantity: 2
  total_price: 59.98
  status: confirmed

two:
  order: pending_two
  user: two
  event: one
  ticket_type: two
  quantity: 1
  total_price: 99.99
  status: pending
```

- [ ] **Step 7: Retire the legacy booking write endpoints**

A `Booking` can no longer exist without an `Order`, so `BookingsController#create` — which builds a bare booking — is now permanently broken. The old `CheckoutController#create` has the same problem: it takes a `booking_id` and pays for a single booking, a shape that no longer exists. Both are removed here rather than left returning 422.

In `app/controllers/api/v1/bookings_controller.rb`, delete the entire `create` action and the entire `update` action. Keep `index`, `show`, and `cancel`. Then narrow `booking_params` to what `cancel` still needs by deleting the `booking_params` private method entirely (neither remaining action uses it).

In `config/routes.rb`, remove `resources :bookings, only: [:create]` from inside the `resources :events do` block, leaving:

```ruby
      resources :events do
        resources :orders, only: [:create]
      end
```

In `app/controllers/api/v1/checkout_controller.rb`, delete the entire `create` action and the entire private `create_checkout_session` method. Keep `webhook` and its private helpers — Task 9 rewrites those.

In `config/routes.rb`, remove the `post 'sessions', to: 'checkout#create'` line, leaving:

```ruby
      namespace :checkout do
        post 'webhook', to: 'checkout#webhook'
      end
```

- [ ] **Step 8: Remove the tests for the deleted endpoints**

In `test/controllers/api/v1/bookings_controller_test.rb`, delete the `should create booking` test and any test exercising `update`. Keep the `index` and `show` tests.

Run: `grep -rn "api_v1_event_bookings_url\|checkout_sessions\|checkout/sessions" test/ app/ config/ || echo "No references remain."`
Expected: `No references remain.`

- [ ] **Step 9: Run the full model and controller suites**

Run: `bin/rails test test/models/ test/controllers/`
Expected: PASS — every test green. The frontend's booking flow is now intentionally unsupported; Plan 2 rebuilds it against orders.

- [ ] **Step 10: Lint and commit**

```bash
bin/rubocop app/models/booking.rb app/controllers/api/v1/bookings_controller.rb app/controllers/api/v1/checkout_controller.rb test/models/booking_test.rb db/migrate/20260815120100_add_order_to_bookings.rb
git add db/migrate/20260815120100_add_order_to_bookings.rb db/schema.rb app/models/booking.rb app/controllers/api/v1/bookings_controller.rb app/controllers/api/v1/checkout_controller.rb config/routes.rb test/models/booking_test.rb test/fixtures/bookings.yml test/controllers/api/v1/bookings_controller_test.rb
git commit -m "feat(orders): link bookings to orders and retire booking-scoped purchase endpoints"
```

---

### Task 3: Tickets table and Ticket model

**Files:**
- Create: `db/migrate/20260815120200_create_tickets.rb`
- Create: `app/models/ticket.rb`
- Create: `test/fixtures/tickets.yml`
- Test: `test/models/ticket_test.rb`

**Interfaces:**
- Consumes: `Booking` from Task 2
- Produces: `Ticket` with `STATUSES`, `Ticket.generate_code`, `#issued?`, `#checked_in?`, `#cancelled?`

- [ ] **Step 1: Write the migration**

Create `db/migrate/20260815120200_create_tickets.rb`:

```ruby
# frozen_string_literal: true

class CreateTickets < ActiveRecord::Migration[7.1]
  def change
    create_table :tickets do |t|
      t.references :booking, null: false, foreign_key: true
      t.string :code, null: false, limit: 15
      t.string :status, null: false, default: 'issued'
      t.datetime :checked_in_at
      t.references :checked_in_by, foreign_key: { to_table: :users }
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :tickets, :code, unique: true
    add_index :tickets, :status
    add_index :tickets, %i[booking_id status]
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== 20260815120200 CreateTickets: migrated`

- [ ] **Step 3: Write the failing test**

Create `test/models/ticket_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class TicketTest < ActiveSupport::TestCase
  test 'generates a code with the EB prefix and twelve base32 characters' do
    code = Ticket.generate_code
    assert_match(/\AEB-[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{12}\z/, code)
  end

  test 'generated codes exclude ambiguous glyphs' do
    200.times do
      body = Ticket.generate_code.delete_prefix('EB-')
      assert_no_match(/[ILOU]/, body)
    end
  end

  test 'assigns a code automatically on create' do
    ticket = Ticket.create!(booking: bookings(:one))
    assert_match(/\AEB-/, ticket.code)
    assert_equal 'issued', ticket.status
  end

  test 'enforces code uniqueness' do
    existing = tickets(:issued_one)
    duplicate = Ticket.new(booking: bookings(:one), code: existing.code)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], 'has already been taken'
  end

  test 'rejects an unknown status' do
    ticket = Ticket.new(booking: bookings(:one), status: 'banana')
    assert_not ticket.valid?
  end

  test 'status predicates reflect the status column' do
    assert tickets(:issued_one).issued?
    assert tickets(:checked_in_one).checked_in?
    assert tickets(:cancelled_one).cancelled?
  end

  test 'exposes event and holder through its booking' do
    ticket = tickets(:issued_one)
    assert_equal events(:one), ticket.event
    assert_equal users(:one), ticket.holder
  end

  test 'scopes filter by status' do
    assert_includes Ticket.issued, tickets(:issued_one)
    assert_not_includes Ticket.issued, tickets(:cancelled_one)
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/models/ticket_test.rb`
Expected: FAIL — `NameError: uninitialized constant Ticket`

- [ ] **Step 5: Write the Ticket model**

Create `app/models/ticket.rb`:

```ruby
# frozen_string_literal: true

class Ticket < ApplicationRecord
  STATUSES = %w[issued checked_in cancelled].freeze

  # Crockford base32 — no I, L, O, or U, so a code read aloud or typed by
  # hand cannot be confused between 1/I, 0/O, or similar.
  CODE_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
  CODE_LENGTH = 12
  CODE_PREFIX = 'EB-'

  belongs_to :booking
  belongs_to :checked_in_by, class_name: 'User', optional: true
  has_one :order, through: :booking
  has_one :event, through: :booking
  has_one :ticket_type, through: :booking
  has_one :holder, through: :booking, source: :user

  before_validation :assign_code, on: :create

  validates :code, presence: true, uniqueness: true,
                   format: { with: /\A#{CODE_PREFIX}[#{CODE_ALPHABET}]{#{CODE_LENGTH}}\z/o }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :issued, -> { where(status: 'issued') }
  scope :checked_in, -> { where(status: 'checked_in') }
  scope :cancelled, -> { where(status: 'cancelled') }

  STATUSES.each do |state|
    define_method(:"#{state}?") { status == state }
  end

  # The unique index is the real guarantee; this loop only avoids the
  # retry storm a blind insert would cause.
  def self.generate_code
    loop do
      body = Array.new(CODE_LENGTH) { CODE_ALPHABET[SecureRandom.random_number(CODE_ALPHABET.size)] }.join
      candidate = "#{CODE_PREFIX}#{body}"
      return candidate unless exists?(code: candidate)
    end
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[checked_in_at code created_at id status updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[booking event holder ticket_type]
  end

  private

  def assign_code
    self.code ||= self.class.generate_code
  end
end
```

- [ ] **Step 6: Create the tickets fixture**

Create `test/fixtures/tickets.yml`:

```yaml
# Read about fixtures at https://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

issued_one:
  booking: one
  code: EB-A7X9K2M4P8Q3
  status: issued

issued_two:
  booking: one
  code: EB-B8Y0M3N5R9S4
  status: issued

checked_in_one:
  booking: two
  code: EB-C9Z1N4P6T0V5
  status: checked_in
  checked_in_at: <%= 1.hour.ago.to_fs(:db) %>
  checked_in_by: two

cancelled_one:
  booking: two
  code: EB-D0A2P5Q7W1X6
  status: cancelled
  cancelled_at: <%= 2.hours.ago.to_fs(:db) %>
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bin/rails test test/models/ticket_test.rb`
Expected: PASS — 8 runs, 0 failures, 0 errors

- [ ] **Step 8: Lint and commit**

```bash
bin/rubocop app/models/ticket.rb test/models/ticket_test.rb db/migrate/20260815120200_create_tickets.rb
git add db/migrate/20260815120200_create_tickets.rb db/schema.rb app/models/ticket.rb test/models/ticket_test.rb test/fixtures/tickets.yml
git commit -m "feat(tickets): add Ticket model with collision-safe code generation"
```

---

### Task 4: Event cancellation cutoff and per-order cap

**Files:**
- Create: `db/migrate/20260815120300_add_ticketing_settings_to_events.rb`
- Modify: `app/models/event.rb`
- Modify: `test/fixtures/events.yml`
- Test: `test/models/event_test.rb`

**Interfaces:**
- Consumes: nothing new
- Produces: `Event#cancellable_until`, `Event#cancellable?(now)`, `Event#ticket_cap`

- [ ] **Step 1: Write the migration**

Create `db/migrate/20260815120300_add_ticketing_settings_to_events.rb`:

```ruby
# frozen_string_literal: true

class AddTicketingSettingsToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :cancel_cutoff_hours, :integer, default: 24
    add_column :events, :max_tickets_per_order, :integer, default: 10
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== 20260815120300 AddTicketingSettingsToEvents: migrated`

- [ ] **Step 3: Write the failing test**

Create `test/models/event_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class EventTest < ActiveSupport::TestCase
  setup { @event = events(:one) }

  test 'defaults the cancel cutoff to 24 hours' do
    assert_equal 24, @event.cancel_cutoff_hours
  end

  test 'defaults the ticket cap to 10' do
    assert_equal 10, @event.ticket_cap
  end

  test 'cancellable_until is the cutoff before the event date' do
    @event.update!(cancel_cutoff_hours: 48)
    assert_equal @event.date - 48.hours, @event.cancellable_until
  end

  test 'cancellable_until is nil when no cutoff is configured' do
    @event.update!(cancel_cutoff_hours: nil)
    assert_nil @event.cancellable_until
  end

  test 'cancellable? is true well before the cutoff' do
    assert @event.cancellable?(@event.date - 72.hours)
  end

  test 'cancellable? is false inside the cutoff window' do
    assert_not @event.cancellable?(@event.date - 1.hour)
  end

  test 'cancellable? is false after the event has started' do
    assert_not @event.cancellable?(@event.date + 1.hour)
  end

  test 'cancellable? is always true when no cutoff is configured' do
    @event.update!(cancel_cutoff_hours: nil)
    assert @event.cancellable?(@event.date + 1.hour)
  end

  test 'ticket_cap returns nil when uncapped' do
    @event.update!(max_tickets_per_order: nil)
    assert_nil @event.ticket_cap
  end

  test 'rejects a negative cutoff' do
    @event.cancel_cutoff_hours = -1
    assert_not @event.valid?
  end

  test 'rejects a zero ticket cap' do
    @event.max_tickets_per_order = 0
    assert_not @event.valid?
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/models/event_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'ticket_cap'`

- [ ] **Step 5: Update the Event model**

In `app/models/event.rb`, add these validations directly after the existing `validates :capacity` line:

```ruby
  validates :cancel_cutoff_hours,
            numericality: { greater_than_or_equal_to: 0, only_integer: true, allow_nil: true }
  validates :max_tickets_per_order,
            numericality: { greater_than: 0, only_integer: true, allow_nil: true }
```

Add these associations directly after the existing `has_many :ticket_types` line:

```ruby
  has_many :orders, dependent: :destroy
```

Add these public methods directly after the existing `available_capacity` method:

```ruby
  # The instant after which cancellation is refused. Nil means cancellation
  # is always permitted.
  def cancellable_until
    return nil if cancel_cutoff_hours.nil?

    date - cancel_cutoff_hours.hours
  end

  def cancellable?(now = Time.current)
    deadline = cancellable_until
    return true if deadline.nil?

    now < deadline
  end

  def ticket_cap
    max_tickets_per_order
  end
```

Then extend the Ransack allow-list so ActiveAdmin can filter on the new columns — replace the existing `ransackable_attributes` body with:

```ruby
    %w[cancel_cutoff_hours capacity created_at date description id location
       max_tickets_per_order name price private updated_at]
```

- [ ] **Step 6: Add cutoff coverage to the events fixture**

In `test/fixtures/events.yml`, add these two lines to the `one:` block:

```yaml
  cancel_cutoff_hours: 24
  max_tickets_per_order: 10
```

And these two to the `two:` block:

```yaml
  cancel_cutoff_hours: 24
  max_tickets_per_order: 4
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bin/rails test test/models/event_test.rb`
Expected: PASS — 11 runs, 0 failures, 0 errors

- [ ] **Step 8: Lint and commit**

```bash
bin/rubocop app/models/event.rb test/models/event_test.rb db/migrate/20260815120300_add_ticketing_settings_to_events.rb
git add db/migrate/20260815120300_add_ticketing_settings_to_events.rb db/schema.rb app/models/event.rb test/models/event_test.rb test/fixtures/events.yml
git commit -m "feat(events): add cancellation cutoff and per-order ticket cap"
```

---

### Task 5: Rewrite inventory accounting

**Files:**
- Modify: `app/models/ticket_type.rb`
- Modify: `app/models/event.rb`
- Test: `test/models/ticket_type_test.rb`

**Interfaces:**
- Consumes: `Booking.holding_inventory` from Task 2
- Produces: corrected `TicketType#available_quantity` and `Event#available_capacity`, plus `TicketType#sold_out?`

The current implementations count every `pending` or `confirmed` booking regardless of whether its order lapsed, so abandoned carts would block inventory forever. This task makes the `holding_inventory` scope the single source of truth.

- [ ] **Step 1: Write the failing test**

Create `test/models/ticket_type_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class TicketTypeTest < ActiveSupport::TestCase
  setup { @ticket_type = ticket_types(:one) }

  test 'available_quantity subtracts bookings on paid orders' do
    # ticket_types(:one) has quantity 100; bookings(:one) holds 2 on a paid order.
    assert_equal 98, @ticket_type.available_quantity
  end

  test 'available_quantity subtracts unexpired pending orders' do
    Booking.create!(
      order: orders(:pending_two), user: users(:two), event: events(:one),
      ticket_type: @ticket_type, quantity: 5, status: 'pending'
    )
    assert_equal 93, @ticket_type.available_quantity
  end

  test 'available_quantity ignores bookings whose order lapsed' do
    Booking.create!(
      order: orders(:pending_two), user: users(:two), event: events(:one),
      ticket_type: @ticket_type, quantity: 5, status: 'pending'
    )
    orders(:pending_two).update!(expires_at: 1.minute.ago)

    assert_equal 98, @ticket_type.available_quantity
  end

  test 'available_quantity ignores cancelled orders' do
    orders(:paid_one).update!(status: 'cancelled')
    assert_equal 100, @ticket_type.available_quantity
  end

  test 'sold_out? is true when nothing remains' do
    @ticket_type.update!(quantity: 2)
    assert @ticket_type.sold_out?
  end

  test 'sold_out? is false while stock remains' do
    assert_not @ticket_type.sold_out?
  end

  test 'available_quantity never reports a negative number' do
    @ticket_type.update!(quantity: 1)
    assert_equal 0, @ticket_type.available_quantity
  end

  test 'event available_capacity follows the same holding rules' do
    event = events(:one)
    # bookings(:one) holds 2 on a paid order, bookings(:two) holds 1 on a
    # pending order that has not lapsed. Capacity is 500.
    assert_equal 497, event.available_capacity

    orders(:pending_two).update!(expires_at: 1.minute.ago)
    assert_equal 498, event.reload.available_capacity
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/models/ticket_type_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'sold_out?'`, and the lapsed-order tests fail because the old implementation still counts them

- [ ] **Step 3: Rewrite the inventory methods**

In `app/models/ticket_type.rb`, replace the existing `available_quantity` method with:

```ruby
  # Inventory is held by bookings whose order is paid, or pending and not yet
  # lapsed. Order.holding_inventory is the single source of truth.
  def available_quantity
    [quantity - bookings.holding_inventory.sum(:quantity), 0].max
  end

  def sold_out?
    available_quantity.zero?
  end
```

In `app/models/event.rb`, replace the existing `available_capacity` method with:

```ruby
  def available_capacity
    return nil unless capacity

    [capacity - bookings.holding_inventory.sum(:quantity), 0].max
  end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/models/ticket_type_test.rb`
Expected: PASS — 8 runs, 0 failures, 0 errors

- [ ] **Step 5: Run the whole model suite for regressions**

Run: `bin/rails test test/models/`
Expected: PASS. The existing `BookingService` tests in `test/services/` may now fail because they predate orders — Task 6 replaces that service, so leave them for now and note the failure count.

- [ ] **Step 6: Lint and commit**

```bash
bin/rubocop app/models/ticket_type.rb app/models/event.rb test/models/ticket_type_test.rb
git add app/models/ticket_type.rb app/models/event.rb test/models/ticket_type_test.rb
git commit -m "fix(inventory): base availability on live orders so lapsed carts release stock"
```

---

### Task 6: Order creation service

**Files:**
- Create: `app/services/orders/creation_service.rb`
- Delete: `app/services/booking_service.rb`
- Delete: `test/services/booking_service_test.rb`
- Test: `test/services/orders/creation_service_test.rb`

**Interfaces:**
- Consumes: `Order`, `Booking`, `TicketType#available_quantity`, `Event#ticket_cap` from Tasks 1–5
- Produces: `Orders::CreationService.new(user:, event:, items:).call` where `items` is an Array of Hashes with `:ticket_type_id` and `:quantity` keys (string or symbol). Returns `{ success: true, order: Order }` or `{ success: false, error: String, code: Symbol }` with `code` in `%i[invalid_items sold_out cap_exceeded event_past]`.

`BookingService` is superseded: it creates a bare `Booking` with no order, which can no longer be valid. It is removed here rather than left to rot.

- [ ] **Step 1: Write the failing test**

Create `test/services/orders/creation_service_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Orders
  class CreationServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @event = events(:one)
      @ga = ticket_types(:one)   # price 29.99, quantity 100
      @vip = ticket_types(:two)  # price 99.99, quantity 20
    end

    def call(items, user: @user, event: @event)
      Orders::CreationService.new(user: user, event: event, items: items).call
    end

    test 'creates a pending order with one booking per tier' do
      result = call([
        { ticket_type_id: @ga.id, quantity: 2 },
        { ticket_type_id: @vip.id, quantity: 1 }
      ])

      assert result[:success], result[:error]
      order = result[:order]
      assert_equal 'pending', order.status
      assert_equal 2, order.bookings.count
      assert_equal @event, order.event
    end

    test 'freezes the total amount across all tiers' do
      result = call([
        { ticket_type_id: @ga.id, quantity: 2 },
        { ticket_type_id: @vip.id, quantity: 1 }
      ])

      expected = (@ga.price * 2) + (@vip.price * 1)
      assert_equal expected, result[:order].total_amount
    end

    test 'sets a fifteen minute hold' do
      freeze_time do
        result = call([{ ticket_type_id: @ga.id, quantity: 1 }])
        assert_in_delta 15.minutes.from_now.to_i, result[:order].expires_at.to_i, 1
      end
    end

    test 'accepts string keys from JSON params' do
      result = call([{ 'ticket_type_id' => @ga.id, 'quantity' => '2' }])
      assert result[:success], result[:error]
      assert_equal 2, result[:order].bookings.first.quantity
    end

    test 'rejects an empty cart' do
      result = call([])
      assert_not result[:success]
      assert_equal :invalid_items, result[:code]
    end

    test 'rejects a tier belonging to another event' do
      other_tier = TicketType.create!(event: events(:two), name: 'Other', price: 5, quantity: 10)
      result = call([{ ticket_type_id: other_tier.id, quantity: 1 }])

      assert_not result[:success]
      assert_equal :invalid_items, result[:code]
    end

    test 'rejects a non-positive quantity' do
      result = call([{ ticket_type_id: @ga.id, quantity: 0 }])
      assert_not result[:success]
      assert_equal :invalid_items, result[:code]
    end

    test 'rejects an order exceeding available stock' do
      @ga.update!(quantity: 3) # bookings(:one) already holds 2, so 1 remains
      result = call([{ ticket_type_id: @ga.id, quantity: 2 }])

      assert_not result[:success]
      assert_equal :sold_out, result[:code]
      assert_match(/General Admission/, result[:error])
    end

    test 'rejects an order exceeding the per-order cap' do
      # events(:one) caps at 10
      result = call([
        { ticket_type_id: @ga.id, quantity: 6 },
        { ticket_type_id: @vip.id, quantity: 5 }
      ])

      assert_not result[:success]
      assert_equal :cap_exceeded, result[:code]
      assert_match(/10/, result[:error])
    end

    test 'allows an order exactly at the cap' do
      result = call([{ ticket_type_id: @ga.id, quantity: 10 }])
      assert result[:success], result[:error]
    end

    test 'ignores the cap when the event is uncapped' do
      @event.update!(max_tickets_per_order: nil)
      result = call([{ ticket_type_id: @ga.id, quantity: 40 }])
      assert result[:success], result[:error]
    end

    test 'rejects an order for an event that already started' do
      @event.update!(date: 1.hour.ago)
      result = call([{ ticket_type_id: @ga.id, quantity: 1 }])

      assert_not result[:success]
      assert_equal :event_past, result[:code]
    end

    test 'marks a zero-total order paid immediately' do
      free_event = events(:two)
      free_tier = TicketType.create!(event: free_event, name: 'Free', price: 0, quantity: 50)

      result = call([{ ticket_type_id: free_tier.id, quantity: 2 }], event: free_event)

      assert result[:success], result[:error]
      assert_equal 'paid', result[:order].status
      assert_equal 'paid', result[:order].payment_status
      assert_not_nil result[:order].paid_at
    end

    test 'writes nothing when any tier in the cart is unavailable' do
      @vip.update!(quantity: 0)

      assert_no_difference ['Order.count', 'Booking.count'] do
        call([
          { ticket_type_id: @ga.id, quantity: 1 },
          { ticket_type_id: @vip.id, quantity: 1 }
        ])
      end
    end

    test 'locks each tier row before reading availability' do
      statements = []
      collector = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }

      ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') do
        call([{ ticket_type_id: @ga.id, quantity: 1 }])
      end

      assert(statements.any? { |sql| sql.include?('FOR UPDATE') },
             'expected the tier row to be locked with SELECT ... FOR UPDATE')
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/services/orders/creation_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant Orders`

- [ ] **Step 3: Write the service**

Create `app/services/orders/creation_service.rb`:

```ruby
# frozen_string_literal: true

module Orders
  # Turns a cart of {ticket_type_id, quantity} pairs into a pending Order with
  # one Booking line item per tier. A zero-total order skips Stripe entirely and
  # is born paid.
  class CreationService
    attr_reader :user, :event, :items

    def initialize(user:, event:, items:)
      @user = user
      @event = event
      @items = Array(items).map { |item| normalise(item) }
    end

    def call
      error = validate_shape
      return error if error

      ActiveRecord::Base.transaction do
        tiers = lock_tiers
        availability_error = validate_availability(tiers)
        raise Halt, availability_error if availability_error

        build_order(tiers)
      end
    rescue Halt => e
      e.payload
    end

    private

    Halt = Class.new(StandardError) do
      attr_reader :payload

      def initialize(payload)
        @payload = payload
        super(payload[:error])
      end
    end

    def normalise(item)
      hash = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
      {
        ticket_type_id: (hash[:ticket_type_id] || hash['ticket_type_id']).to_i,
        quantity: (hash[:quantity] || hash['quantity']).to_i
      }
    end

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def validate_shape
      return failure(:invalid_items, 'Your cart is empty') if items.empty?
      return failure(:invalid_items, 'Every ticket quantity must be at least 1') if items.any? { |i| i[:quantity] < 1 }
      return failure(:event_past, 'This event has already started') if event.date.present? && event.date <= Time.current

      cap = event.ticket_cap
      total = items.sum { |i| i[:quantity] }
      return failure(:cap_exceeded, "You can order at most #{cap} tickets for this event") if cap && total > cap

      nil
    end

    # Row-locks each tier so two concurrent buyers cannot both read the same
    # availability and both succeed.
    def lock_tiers
      event.ticket_types.where(id: items.map { |i| i[:ticket_type_id] }).each(&:lock!).index_by(&:id)
    end

    def validate_availability(tiers)
      items.each do |item|
        tier = tiers[item[:ticket_type_id]]
        return failure(:invalid_items, 'One of the selected ticket types is not available for this event') if tier.nil?

        if tier.available_quantity < item[:quantity]
          return failure(:sold_out, "Only #{tier.available_quantity} #{tier.name} ticket(s) remain")
        end
      end

      nil
    end

    def build_order(tiers)
      total = items.sum { |item| tiers[item[:ticket_type_id]].price * item[:quantity] }
      free = total.zero?

      order = Order.create!(
        user: user,
        event: event,
        status: free ? 'paid' : 'pending',
        payment_status: free ? 'paid' : 'unpaid',
        total_amount: total,
        expires_at: Order.default_expiry,
        paid_at: free ? Time.current : nil
      )

      items.each do |item|
        order.bookings.create!(
          user: user,
          event: event,
          ticket_type: tiers[item[:ticket_type_id]],
          quantity: item[:quantity],
          status: free ? 'confirmed' : 'pending'
        )
      end

      { success: true, order: order.reload }
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/services/orders/creation_service_test.rb`
Expected: PASS — 16 runs, 0 failures, 0 errors

- [ ] **Step 5: Remove the superseded BookingService**

```bash
git rm app/services/booking_service.rb test/services/booking_service_test.rb
```

- [ ] **Step 6: Verify nothing still references it**

Run: `grep -rn "BookingService" app/ test/ lib/ || echo "No references remain."`
Expected: `No references remain.`

- [ ] **Step 7: Lint and commit**

```bash
bin/rubocop app/services/orders/creation_service.rb test/services/orders/creation_service_test.rb
git add app/services/orders/creation_service.rb test/services/orders/creation_service_test.rb
git commit -m "feat(orders): add creation service with locking, caps, and free-event path"
```

---

### Task 7: Orders API endpoints

**Files:**
- Create: `app/controllers/api/v1/orders_controller.rb`
- Create: `app/policies/order_policy.rb`
- Create: `app/serializers/order_serializer.rb`
- Modify: `app/serializers/booking_serializer.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/api/v1/orders_controller_test.rb`

**Interfaces:**
- Consumes: `Orders::CreationService` from Task 6
- Produces: `POST /api/v1/events/:event_id/orders`, `GET /api/v1/orders`, `GET /api/v1/orders/:id`; `OrderPolicy` with `#show?`, `#create?`, `#cancel?`; `OrderSerializer` emitting `id`, `reference`, `status`, `payment_status`, `total_amount`, `currency`, `expires_at`, `paid_at`, `cancellable`, `bookings`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/api/v1/orders_controller_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class OrdersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
        @other = users(:two)
        @event = events(:one)
        @ga = ticket_types(:one)
      end

      def auth_headers(user)
        token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        { 'Authorization' => "Bearer #{token}" }
      end

      test 'create requires authentication' do
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 1 }] }, as: :json
        assert_response :unauthorized
      end

      test 'create returns a pending order' do
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 2 }] },
             headers: auth_headers(@user), as: :json

        assert_response :created
        body = response.parsed_body
        assert_equal 'pending', body['status']
        assert_equal 1, body['bookings'].size
        assert_equal '59.98', body['total_amount'].to_s
      end

      test 'create rejects an oversized cart with the cap message' do
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 99 }] },
             headers: auth_headers(@user), as: :json

        assert_response :unprocessable_entity
        assert_equal 'cap_exceeded', response.parsed_body['code']
      end

      test 'create reports remaining stock when sold out' do
        @ga.update!(quantity: 3)
        post "/api/v1/events/#{@event.id}/orders",
             params: { items: [{ ticket_type_id: @ga.id, quantity: 2 }] },
             headers: auth_headers(@user), as: :json

        assert_response :unprocessable_entity
        assert_equal 'sold_out', response.parsed_body['code']
      end

      test 'index lists only my orders' do
        get '/api/v1/orders', headers: auth_headers(@user), as: :json

        assert_response :success
        ids = response.parsed_body['orders'].map { |o| o['id'] }
        assert_includes ids, orders(:paid_one).id
        assert_not_includes ids, orders(:pending_two).id
      end

      test 'index is paginated' do
        get '/api/v1/orders', headers: auth_headers(@user), as: :json
        assert_response :success
        assert response.parsed_body.key?('meta')
      end

      test 'show returns my order with bookings and tickets' do
        get "/api/v1/orders/#{orders(:paid_one).id}", headers: auth_headers(@user), as: :json

        assert_response :success
        body = response.parsed_body
        assert_equal orders(:paid_one).id, body['id']
        assert_equal 2, body['bookings'].first['tickets'].size
      end

      test 'show forbids another users order' do
        get "/api/v1/orders/#{orders(:paid_one).id}", headers: auth_headers(@other), as: :json
        assert_response :not_found
      end

      test 'show exposes whether the order can still be cancelled' do
        get "/api/v1/orders/#{orders(:paid_one).id}", headers: auth_headers(@user), as: :json
        assert_includes [true, false], response.parsed_body['cancellable']
      end
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/api/v1/orders_controller_test.rb`
Expected: FAIL — routing error, no route matches `POST /api/v1/events/1/orders`

- [ ] **Step 3: Add the routes**

In `config/routes.rb`, inside the `namespace :v1` block, replace the existing `resources :events do ... end` block with:

```ruby
      resources :events do
        resources :bookings, only: [:create]
        resources :orders, only: [:create]
      end

      resources :orders, only: %i[index show destroy]
```

- [ ] **Step 4: Write the policy**

Create `app/policies/order_policy.rb`:

```ruby
# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    owner? || user.admin?
  end

  def create?
    true
  end

  def cancel?
    owner? || user.admin?
  end

  def destroy?
    cancel?
  end

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(user_id: user.id)
    end
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

- [ ] **Step 5: Write the serializers**

Create `app/serializers/order_serializer.rb`:

```ruby
# frozen_string_literal: true

class OrderSerializer < ActiveModel::Serializer
  attributes :id, :reference, :status, :payment_status, :total_amount,
             :currency, :expires_at, :paid_at, :cancelled_at, :refunded_at,
             :cancellable, :ticket_count

  belongs_to :event
  has_many :bookings

  def cancellable
    object.paid? && object.event.cancellable?
  end

  def ticket_count
    object.bookings.sum(:quantity)
  end
end
```

Replace `app/serializers/booking_serializer.rb` with:

```ruby
# frozen_string_literal: true

class BookingSerializer < ActiveModel::Serializer
  attributes :id, :quantity, :total_price, :status, :created_at

  belongs_to :ticket_type
  has_many :tickets
end
```

- [ ] **Step 6: Write the controller**

Create `app/controllers/api/v1/orders_controller.rb`:

```ruby
# frozen_string_literal: true

module Api
  module V1
    class OrdersController < BaseController
      include Pagy::Backend

      def index
        scope = policy_scope(Order).includes(:event, bookings: %i[ticket_type tickets]).order(created_at: :desc)
        pagy, orders = pagy(scope)

        render json: {
          orders: ActiveModelSerializers::SerializableResource.new(orders, each_serializer: OrderSerializer),
          meta: { page: pagy.page, pages: pagy.pages, count: pagy.count, items: pagy.vars[:items] }
        }
      end

      def show
        order = policy_scope(Order).includes(bookings: %i[ticket_type tickets]).find(params[:id])
        authorize order
        render json: order, serializer: OrderSerializer
      end

      def create
        event = Event.find(params[:event_id])
        authorize Order.new(user: current_user, event: event), :create?

        result = Orders::CreationService.new(user: current_user, event: event, items: order_items).call

        if result[:success]
          render json: result[:order], serializer: OrderSerializer, status: :created
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end

      private

      def order_items
        params.require(:items).map { |item| item.permit(:ticket_type_id, :quantity).to_h }
      end
    end
  end
end
```

- [ ] **Step 7: Confirm Pundit's scoping helpers are available**

`Api::V1::BookingsController` already calls `authorize`, so Pundit is included somewhere up the chain. `policy_scope` ships in the same module, so it is probably already available. Verify before changing anything:

Run: `grep -rn "Pundit" app/controllers/application_controller.rb app/controllers/api/v1/base_controller.rb`

If `ApplicationController` includes `Pundit` or `Pundit::Authorization`, **make no change — skip to Step 8.**

If neither file mentions Pundit, add this line to `app/controllers/api/v1/base_controller.rb` directly beneath the existing `protect_from_forgery with: :null_session` line:

```ruby
      include Pundit::Authorization
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `bin/rails test test/controllers/api/v1/orders_controller_test.rb`
Expected: PASS — 9 runs, 0 failures, 0 errors

- [ ] **Step 9: Lint and commit**

```bash
bin/rubocop app/controllers/api/v1/orders_controller.rb app/policies/order_policy.rb app/serializers/ test/controllers/api/v1/orders_controller_test.rb
git add app/controllers/api/v1/orders_controller.rb app/controllers/api/v1/base_controller.rb app/policies/order_policy.rb app/serializers/order_serializer.rb app/serializers/booking_serializer.rb config/routes.rb test/controllers/api/v1/orders_controller_test.rb
git commit -m "feat(orders): add order creation, listing, and detail endpoints"
```

---

### Task 8: Stripe checkout for orders

**Files:**
- Create: `app/services/orders/checkout_service.rb`
- Modify: `Gemfile` (add `webmock` to the test group)
- Modify: `test/test_helper.rb` (enable WebMock)
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/orders_controller.rb`
- Test: `test/services/orders/checkout_service_test.rb`

**Interfaces:**
- Consumes: `Order` from Task 1
- Produces: `Orders::CheckoutService.new(order:).call` returning `{ success: true, checkout_url: String, session_id: String }` or `{ success: false, error: String, code: Symbol }` with `code` in `%i[not_payable stripe_error]`; endpoint `POST /api/v1/orders/:id/checkout`

- [ ] **Step 1: Add WebMock**

In `Gemfile`, inside the existing `group :test do` block, add:

```ruby
  gem 'webmock', '~> 3.19'
```

Run: `bundle install`
Expected: `Bundle complete!` and `webmock` appears in `Gemfile.lock`

- [ ] **Step 2: Enable WebMock in the test helper**

In `test/test_helper.rb`, add directly after the `require 'rails/test_help'` line:

```ruby
require 'webmock/minitest'

# No test may reach the network. Stripe is stubbed per-test.
WebMock.disable_net_connect!(allow_localhost: true)
```

- [ ] **Step 3: Write the failing test**

Create `test/services/orders/checkout_service_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Orders
  class CheckoutServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:pending_two)
      @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:one), quantity: 2, status: 'pending'
      )
    end

    def stub_session(id: 'cs_test_123', url: 'https://checkout.stripe.com/c/pay/cs_test_123')
      stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { id: id, url: url, object: 'checkout.session' }.to_json
        )
    end

    test 'returns the checkout url and persists the session id' do
      stub_session
      result = Orders::CheckoutService.new(order: @order).call

      assert result[:success], result[:error]
      assert_equal 'https://checkout.stripe.com/c/pay/cs_test_123', result[:checkout_url]
      assert_equal 'cs_test_123', @order.reload.stripe_checkout_session_id
    end

    test 'sends one line item per booking' do
      stub_session
      Orders::CheckoutService.new(order: @order).call

      assert_requested(:post, 'https://api.stripe.com/v1/checkout/sessions') do |req|
        req.body.include?('line_items[0]') && req.body.include?('line_items[1]')
      end
    end

    test 'refuses an order that is already paid' do
      @order.update!(status: 'paid')
      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_payable, result[:code]
    end

    test 'refuses an order whose hold has lapsed' do
      @order.update!(expires_at: 1.minute.ago)
      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_payable, result[:code]
    end

    test 'refuses a free order' do
      @order.update!(total_amount: 0)
      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_payable, result[:code]
    end

    test 'surfaces a Stripe failure without changing the order' do
      stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
        .to_return(
          status: 402,
          headers: { 'Content-Type' => 'application/json' },
          body: { error: { message: 'Your card was declined', type: 'card_error' } }.to_json
        )

      result = Orders::CheckoutService.new(order: @order).call

      assert_not result[:success]
      assert_equal :stripe_error, result[:code]
      assert_nil @order.reload.stripe_checkout_session_id
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/services/orders/checkout_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant Orders::CheckoutService`

- [ ] **Step 5: Write the service**

Create `app/services/orders/checkout_service.rb`:

```ruby
# frozen_string_literal: true

module Orders
  # Exchanges a pending, unexpired, non-free order for a Stripe Checkout
  # Session. One Stripe line item per Booking, so the buyer sees each tier
  # itemised on Stripe's page.
  class CheckoutService
    attr_reader :order

    def initialize(order:)
      @order = order
    end

    def call
      return failure(:not_payable, 'This order is no longer awaiting payment') unless payable?

      session = Stripe::Checkout::Session.create(session_params)
      order.update!(stripe_checkout_session_id: session.id)

      { success: true, checkout_url: session.url, session_id: session.id }
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e) if defined?(Sentry)
      failure(:stripe_error, e.message)
    end

    private

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def payable?
      order.pending? && !order.free? && order.expires_at > Time.current
    end

    def frontend_url
      ENV.fetch('FRONTEND_URL', 'http://localhost:3001')
    end

    def session_params
      {
        mode: 'payment',
        customer_email: order.user.email,
        line_items: order.bookings.map { |booking| line_item(booking) },
        metadata: { order_id: order.id, user_id: order.user_id },
        success_url: "#{frontend_url}/checkout/success?order_id=#{order.id}&session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{frontend_url}/checkout/cancel?order_id=#{order.id}"
      }
    end

    def line_item(booking)
      {
        price_data: {
          currency: order.currency,
          product_data: {
            name: "#{booking.event.name} — #{booking.ticket_type.name}",
            metadata: { event_id: booking.event_id, ticket_type_id: booking.ticket_type_id }
          },
          unit_amount: (booking.ticket_type.price * 100).to_i
        },
        quantity: booking.quantity
      }
    end
  end
end
```

- [ ] **Step 6: Add the checkout route**

In `config/routes.rb`, replace the `resources :orders, only: %i[index show destroy]` line added in Task 7 with:

```ruby
      resources :orders, only: %i[index show destroy] do
        member do
          post :checkout
        end
      end
```

- [ ] **Step 7: Add the controller action**

In `app/controllers/api/v1/orders_controller.rb`, add this public action directly after `create`:

```ruby
      def checkout
        order = policy_scope(Order).find(params[:id])
        authorize order, :show?

        result = Orders::CheckoutService.new(order: order).call

        if result[:success]
          render json: { checkout_url: result[:checkout_url], session_id: result[:session_id] }
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `bin/rails test test/services/orders/checkout_service_test.rb`
Expected: PASS — 6 runs, 0 failures, 0 errors

- [ ] **Step 9: Run the full suite to confirm WebMock broke nothing**

Run: `bin/rails test`
Expected: PASS across all files. If any pre-existing test now fails with `WebMock::NetConnectNotAllowedError`, stub that request in the failing test rather than loosening the global block.

- [ ] **Step 10: Lint and commit**

```bash
bin/rubocop app/services/orders/checkout_service.rb test/services/orders/checkout_service_test.rb
git add Gemfile Gemfile.lock test/test_helper.rb app/services/orders/checkout_service.rb app/controllers/api/v1/orders_controller.rb config/routes.rb test/services/orders/checkout_service_test.rb
git commit -m "feat(orders): create Stripe checkout sessions per order"
```

---

### Task 9: Payment completion and webhook

**Files:**
- Create: `app/services/orders/payment_completion_service.rb`
- Modify: `app/controllers/api/v1/checkout_controller.rb`
- Test: `test/services/orders/payment_completion_service_test.rb`
- Test: `test/controllers/api/v1/checkout_webhook_test.rb`

**Interfaces:**
- Consumes: `Order` from Task 1
- Produces: `Orders::PaymentCompletionService.new(order:, payment_intent_id: nil).call` returning `{ success: true, order: Order }`; idempotent — a second call on an already-paid order is a no-op returning success

Ticket issuance is wired into this service in Task 11; this task establishes the state transition alone.

- [ ] **Step 1: Write the failing service test**

Create `test/services/orders/payment_completion_service_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Orders
  class PaymentCompletionServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:pending_two)
      @booking = @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:one), quantity: 2, status: 'pending'
      )
    end

    def complete(intent: 'pi_test_abc')
      Orders::PaymentCompletionService.new(order: @order, payment_intent_id: intent).call
    end

    test 'marks the order paid and stamps the timestamp' do
      freeze_time do
        result = complete
        assert result[:success], result[:error]
        @order.reload
        assert_equal 'paid', @order.status
        assert_equal 'paid', @order.payment_status
        assert_equal Time.current.to_i, @order.paid_at.to_i
      end
    end

    test 'records the payment intent id' do
      complete(intent: 'pi_live_xyz')
      assert_equal 'pi_live_xyz', @order.reload.stripe_payment_intent_id
    end

    test 'cascades bookings to confirmed' do
      complete
      assert_equal 'confirmed', @booking.reload.status
    end

    test 'is idempotent when the order is already paid' do
      complete
      first_paid_at = @order.reload.paid_at

      travel 1.hour do
        result = complete
        assert result[:success]
        assert_equal first_paid_at.to_i, @order.reload.paid_at.to_i
      end
    end

    test 'refuses to resurrect a cancelled order' do
      @order.update!(status: 'cancelled')
      result = complete

      assert_not result[:success]
      assert_equal :not_completable, result[:code]
    end

    test 'completes an order whose hold lapsed but whose payment landed' do
      @order.update!(expires_at: 1.minute.ago)
      result = complete

      assert result[:success], result[:error]
      assert_equal 'paid', @order.reload.status
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/services/orders/payment_completion_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant Orders::PaymentCompletionService`

- [ ] **Step 3: Write the service**

Create `app/services/orders/payment_completion_service.rb`:

```ruby
# frozen_string_literal: true

module Orders
  # Drives an order from pending to paid. Invoked by the Stripe webhook, which
  # Stripe may deliver more than once, so every path here is idempotent.
  #
  # An order whose 15-minute hold lapsed is still completed: the buyer's money
  # arrived, and honouring the sale is preferable to a refund. Oversell is
  # possible in that narrow window and is accepted deliberately.
  class PaymentCompletionService
    attr_reader :order, :payment_intent_id

    def initialize(order:, payment_intent_id: nil)
      @order = order
      @payment_intent_id = payment_intent_id
    end

    def call
      return { success: true, order: order } if order.paid?
      return failure(:not_completable, 'This order can no longer be paid') unless completable?

      ActiveRecord::Base.transaction do
        order.update!(
          status: 'paid',
          payment_status: 'paid',
          paid_at: Time.current,
          stripe_payment_intent_id: payment_intent_id.presence || order.stripe_payment_intent_id
        )
        order.bookings.update_all(status: 'confirmed', updated_at: Time.current)
      end

      { success: true, order: order.reload }
    end

    private

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def completable?
      order.pending? || order.expired?
    end
  end
end
```

- [ ] **Step 4: Run the service test to verify it passes**

Run: `bin/rails test test/services/orders/payment_completion_service_test.rb`
Expected: PASS — 6 runs, 0 failures, 0 errors

- [ ] **Step 5: Write the failing webhook test**

Create `test/controllers/api/v1/checkout_webhook_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class CheckoutWebhookTest < ActionDispatch::IntegrationTest
      setup do
        @order = orders(:pending_two)
        @order.update!(stripe_checkout_session_id: 'cs_test_hook')
        @order.bookings.create!(
          user: users(:two), event: events(:one),
          ticket_type: ticket_types(:one), quantity: 1, status: 'pending'
        )
      end

      def completed_event(order_id: @order.id)
        Stripe::Event.construct_from(
          type: 'checkout.session.completed',
          data: {
            object: {
              id: 'cs_test_hook',
              object: 'checkout.session',
              payment_intent: 'pi_test_hook',
              metadata: { 'order_id' => order_id.to_s }
            }
          }
        )
      end

      def post_webhook(stripe_event)
        Stripe::Webhook.stub(:construct_event, stripe_event) do
          post '/api/v1/checkout/webhook',
               params: '{}',
               headers: { 'HTTP_STRIPE_SIGNATURE' => 't=1,v1=fake', 'CONTENT_TYPE' => 'application/json' }
        end
      end

      test 'marks the order paid' do
        post_webhook(completed_event)

        assert_response :success
        assert_equal 'paid', @order.reload.status
        assert_equal 'pi_test_hook', @order.stripe_payment_intent_id
      end

      test 'is idempotent across duplicate deliveries' do
        post_webhook(completed_event)
        paid_at = @order.reload.paid_at

        travel 1.hour do
          post_webhook(completed_event)
          assert_response :success
          assert_equal paid_at.to_i, @order.reload.paid_at.to_i
        end
      end

      test 'acknowledges an unknown order without raising' do
        post_webhook(completed_event(order_id: 999_999))
        assert_response :success
      end

      test 'rejects an invalid signature' do
        Stripe::Webhook.stub(:construct_event, ->(*) { raise Stripe::SignatureVerificationError.new('bad', 'sig') }) do
          post '/api/v1/checkout/webhook',
               params: '{}',
               headers: { 'HTTP_STRIPE_SIGNATURE' => 'nonsense', 'CONTENT_TYPE' => 'application/json' }
        end

        assert_response :bad_request
      end
    end
  end
end
```

- [ ] **Step 6: Run the webhook test to verify it fails**

Run: `bin/rails test test/controllers/api/v1/checkout_webhook_test.rb`
Expected: FAIL — the order stays `pending` because the handler only knows about bookings

- [ ] **Step 7: Extend the webhook handler**

In `app/controllers/api/v1/checkout_controller.rb`, replace the entire private `handle_webhook_event` method (and any `handle_*` helpers it delegates to for `checkout.session.completed`) with:

```ruby
      def handle_webhook_event(event)
        case event.type
        when 'checkout.session.completed'
          complete_order(event.data.object)
        when 'charge.refunded'
          record_refund(event.data.object)
        end
      end

      def complete_order(session)
        order = find_order_for(session)
        return if order.nil?

        Orders::PaymentCompletionService.new(
          order: order,
          payment_intent_id: session.respond_to?(:payment_intent) ? session.payment_intent : nil
        ).call
      end

      def record_refund(charge)
        intent = charge.respond_to?(:payment_intent) ? charge.payment_intent : nil
        return if intent.blank?

        order = Order.find_by(stripe_payment_intent_id: intent)
        return if order.nil? || order.refunded?

        order.update!(status: 'refunded', payment_status: 'refunded', refunded_at: Time.current)
      end

      def find_order_for(session)
        id = session.metadata.respond_to?(:[]) ? session.metadata['order_id'] : nil
        return Order.find_by(id: id) if id.present?

        Order.find_by(stripe_checkout_session_id: session.id)
      end
```

- [ ] **Step 8: Run the webhook test to verify it passes**

Run: `bin/rails test test/controllers/api/v1/checkout_webhook_test.rb`
Expected: PASS — 4 runs, 0 failures, 0 errors

- [ ] **Step 9: Lint and commit**

```bash
bin/rubocop app/services/orders/payment_completion_service.rb app/controllers/api/v1/checkout_controller.rb test/services/orders/payment_completion_service_test.rb test/controllers/api/v1/checkout_webhook_test.rb
git add app/services/orders/payment_completion_service.rb app/controllers/api/v1/checkout_controller.rb test/services/orders/payment_completion_service_test.rb test/controllers/api/v1/checkout_webhook_test.rb
git commit -m "feat(orders): complete payment idempotently from the Stripe webhook"
```

---

### Task 10: Expire abandoned orders

**Files:**
- Create: `app/jobs/order_expiry_job.rb`
- Modify: `Gemfile` (add `sidekiq-cron`)
- Create: `config/initializers/sidekiq_cron.rb`
- Test: `test/jobs/order_expiry_job_test.rb`

**Interfaces:**
- Consumes: `Order.sweepable` from Task 1
- Produces: `OrderExpiryJob.perform_now` marking lapsed pending orders `expired` and returning the count

- [ ] **Step 1: Add sidekiq-cron**

In `Gemfile`, directly beneath the existing `gem 'sidekiq', '~> 7.0'` line, add:

```ruby
gem 'sidekiq-cron', '~> 1.12'
```

Run: `bundle install`
Expected: `Bundle complete!`

- [ ] **Step 2: Write the failing test**

Create `test/jobs/order_expiry_job_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class OrderExpiryJobTest < ActiveJob::TestCase
  test 'expires a pending order whose hold lapsed' do
    order = orders(:pending_two)
    order.update!(expires_at: 1.minute.ago)

    OrderExpiryJob.perform_now

    assert_equal 'expired', order.reload.status
  end

  test 'leaves an unexpired pending order alone' do
    order = orders(:pending_two)
    order.update!(expires_at: 5.minutes.from_now)

    OrderExpiryJob.perform_now

    assert_equal 'pending', order.reload.status
  end

  test 'never touches a paid order' do
    order = orders(:paid_one)
    order.update!(expires_at: 1.hour.ago)

    OrderExpiryJob.perform_now

    assert_equal 'paid', order.reload.status
  end

  test 'releases the inventory it was holding' do
    order = orders(:pending_two)
    order.bookings.create!(
      user: users(:two), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 5, status: 'pending'
    )
    order.update!(expires_at: 1.minute.ago)

    before = ticket_types(:one).available_quantity
    OrderExpiryJob.perform_now

    assert_equal before + 5, ticket_types(:one).reload.available_quantity
  end

  test 'cascades bookings to cancelled' do
    order = orders(:pending_two)
    booking = order.bookings.create!(
      user: users(:two), event: events(:one),
      ticket_type: ticket_types(:one), quantity: 1, status: 'pending'
    )
    order.update!(expires_at: 1.minute.ago)

    OrderExpiryJob.perform_now

    assert_equal 'cancelled', booking.reload.status
  end

  test 'returns the number of orders it expired' do
    orders(:pending_two).update!(expires_at: 1.minute.ago)
    assert_equal 1, OrderExpiryJob.perform_now
  end

  test 'warns when a checkout session was started but never completed' do
    order = orders(:pending_two)
    order.update!(expires_at: 1.minute.ago, stripe_checkout_session_id: 'cs_abandoned')

    messages = []
    Rails.logger.stub(:warn, ->(msg) { messages << msg }) do
      OrderExpiryJob.perform_now
    end

    assert(messages.any? { |m| m.include?('cs_abandoned') },
           'expected a warning naming the abandoned checkout session')
  end
end
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bin/rails test test/jobs/order_expiry_job_test.rb`
Expected: FAIL — `NameError: uninitialized constant OrderExpiryJob`

- [ ] **Step 4: Write the job**

Create `app/jobs/order_expiry_job.rb`:

```ruby
# frozen_string_literal: true

# Sweeps orders whose 15-minute payment hold lapsed. Expiring an order is what
# releases its inventory back to the pool — Order.holding_inventory already
# ignores lapsed rows, so this job is bookkeeping that makes the state visible
# and cascades the change to bookings.
class OrderExpiryJob < ApplicationJob
  queue_as :default

  def perform
    count = 0

    Order.sweepable.find_each do |order|
      ActiveRecord::Base.transaction do
        order.update!(status: 'expired')
        order.bookings.update_all(status: 'cancelled', updated_at: Time.current)
      end
      report_abandoned_session(order)
      count += 1
    end

    count
  end

  private

  # An order that reached Stripe but never came back means either the buyer
  # walked away or a webhook was lost. The two are indistinguishable from here,
  # so this is a warning rather than an error — but a spike in these is the
  # first sign that webhook delivery is broken.
  def report_abandoned_session(order)
    return if order.stripe_checkout_session_id.blank?

    message = "Order #{order.id} expired with an unconsumed Stripe session " \
              "#{order.stripe_checkout_session_id}"
    Rails.logger.warn(message)
    Sentry.capture_message(message, level: :warning) if defined?(Sentry)
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/jobs/order_expiry_job_test.rb`
Expected: PASS — 6 runs, 0 failures, 0 errors

- [ ] **Step 6: Schedule the job every minute**

Create `config/initializers/sidekiq_cron.rb`:

```ruby
# frozen_string_literal: true

# Only the Sidekiq process should load the schedule; the web process would
# otherwise register duplicate entries on every boot.
if defined?(Sidekiq::Cron) && Sidekiq.server?
  Sidekiq::Cron::Job.create(
    name: 'Expire abandoned orders',
    cron: '* * * * *',
    class: 'OrderExpiryJob'
  )
end
```

- [ ] **Step 7: Verify the app still boots**

Run: `bin/rails runner 'puts "boot ok"'`
Expected: `boot ok`

- [ ] **Step 8: Lint and commit**

```bash
bin/rubocop app/jobs/order_expiry_job.rb config/initializers/sidekiq_cron.rb test/jobs/order_expiry_job_test.rb
git add Gemfile Gemfile.lock app/jobs/order_expiry_job.rb config/initializers/sidekiq_cron.rb test/jobs/order_expiry_job_test.rb
git commit -m "feat(orders): expire abandoned orders on a schedule to release inventory"
```

---

### Task 11: Issue tickets on payment

**Files:**
- Create: `app/services/tickets/issuance_service.rb`
- Modify: `app/services/orders/payment_completion_service.rb`
- Test: `test/services/tickets/issuance_service_test.rb`

**Interfaces:**
- Consumes: `Ticket` from Task 3, `Orders::PaymentCompletionService` from Task 9
- Produces: `Tickets::IssuanceService.new(order:).call` returning `{ success: true, tickets: Array<Ticket> }`; idempotent — a second call returns the existing tickets without creating more

- [ ] **Step 1: Add the issuance marker column**

The service is idempotent on this column, so it must exist before the test can run.

Create `db/migrate/20260815120400_add_tickets_issued_at_to_orders.rb`:

```ruby
# frozen_string_literal: true

class AddTicketsIssuedAtToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :tickets_issued_at, :datetime
  end
end
```

Run: `bin/rails db:migrate`
Expected: `== 20260815120400 AddTicketsIssuedAtToOrders: migrated`

- [ ] **Step 2: Write the failing test**

Create `test/services/tickets/issuance_service_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Tickets
  class IssuanceServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:pending_two)
      @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:one), quantity: 3, status: 'confirmed'
      )
      @order.bookings.create!(
        user: users(:two), event: events(:one),
        ticket_type: ticket_types(:two), quantity: 2, status: 'confirmed'
      )
      @order.update!(status: 'paid', payment_status: 'paid', paid_at: Time.current)
    end

    test 'creates one ticket per unit of quantity across every booking' do
      result = Tickets::IssuanceService.new(order: @order).call

      assert result[:success], result[:error]
      assert_equal 5, result[:tickets].size
      assert_equal 5, @order.reload.tickets.count
    end

    test 'gives every ticket a distinct code' do
      result = Tickets::IssuanceService.new(order: @order).call
      codes = result[:tickets].map(&:code)

      assert_equal codes.size, codes.uniq.size
      codes.each { |code| assert_match(/\AEB-[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{12}\z/, code) }
    end

    test 'issues every ticket in the issued state' do
      result = Tickets::IssuanceService.new(order: @order).call
      assert(result[:tickets].all?(&:issued?))
    end

    test 'is idempotent' do
      Tickets::IssuanceService.new(order: @order).call

      assert_no_difference 'Ticket.count' do
        result = Tickets::IssuanceService.new(order: @order).call
        assert result[:success]
        assert_equal 5, result[:tickets].size
      end
    end

    test 'refuses to issue for an unpaid order' do
      @order.update!(status: 'pending', payment_status: 'unpaid', paid_at: nil)
      result = Tickets::IssuanceService.new(order: @order).call

      assert_not result[:success]
      assert_equal :not_paid, result[:code]
      assert_equal 0, @order.reload.tickets.count
    end

    test 'payment completion issues tickets automatically' do
      @order.update!(status: 'pending', payment_status: 'unpaid', paid_at: nil, tickets_issued_at: nil)

      Orders::PaymentCompletionService.new(order: @order, payment_intent_id: 'pi_x').call

      assert_equal 5, @order.reload.tickets.count
    end
  end
end
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bin/rails test test/services/tickets/issuance_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant Tickets::IssuanceService`

- [ ] **Step 4: Write the service**

Create `app/services/tickets/issuance_service.rb`:

```ruby
# frozen_string_literal: true

module Tickets
  # Expands a paid order's bookings into individual scanable tickets: a booking
  # for 3 General Admission becomes 3 Ticket rows, each with its own code.
  #
  # Stripe can deliver the same webhook twice, so this is idempotent on
  # orders.tickets_issued_at rather than on a count comparison.
  class IssuanceService
    attr_reader :order

    def initialize(order:)
      @order = order
    end

    def call
      return { success: true, tickets: order.tickets.to_a } if order.tickets_issued_at.present?
      return failure(:not_paid, 'Tickets are only issued for paid orders') unless order.paid?

      tickets = ActiveRecord::Base.transaction do
        created = order.bookings.flat_map { |booking| issue_for(booking) }
        order.update!(tickets_issued_at: Time.current)
        created
      end

      { success: true, tickets: tickets }
    end

    private

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def issue_for(booking)
      Array.new(booking.quantity) { booking.tickets.create! }
    end
  end
end
```

- [ ] **Step 5: Add the tickets association to Booking**

In `app/models/booking.rb`, directly beneath the `belongs_to :order` line added in Task 2, add:

```ruby
  has_many :tickets, dependent: :destroy
```

- [ ] **Step 6: Wire issuance into payment completion**


In `app/services/orders/payment_completion_service.rb`, replace the `call` method with:

```ruby
    def call
      return { success: true, order: order } if order.paid? && order.tickets_issued_at.present?
      return failure(:not_completable, 'This order can no longer be paid') unless completable? || order.paid?

      ActiveRecord::Base.transaction do
        unless order.paid?
          order.update!(
            status: 'paid',
            payment_status: 'paid',
            paid_at: Time.current,
            stripe_payment_intent_id: payment_intent_id.presence || order.stripe_payment_intent_id
          )
          order.bookings.update_all(status: 'confirmed', updated_at: Time.current)
        end
      end

      Tickets::IssuanceService.new(order: order.reload).call

      { success: true, order: order.reload }
    end
```

- [ ] **Step 7: Run both service tests to verify they pass**

Run: `bin/rails test test/services/tickets/issuance_service_test.rb test/services/orders/payment_completion_service_test.rb`
Expected: PASS — 12 runs total, 0 failures, 0 errors

- [ ] **Step 8: Lint and commit**

```bash
bin/rubocop app/services/tickets/issuance_service.rb app/services/orders/payment_completion_service.rb app/models/booking.rb test/services/tickets/issuance_service_test.rb
git add db/migrate/20260815120400_add_tickets_issued_at_to_orders.rb db/schema.rb app/services/tickets/issuance_service.rb app/services/orders/payment_completion_service.rb app/models/booking.rb test/services/tickets/issuance_service_test.rb
git commit -m "feat(tickets): issue individual tickets when an order is paid"
```

---

### Task 12: Render a ticket as a PDF

**Files:**
- Modify: `Gemfile` (add `prawn`, `prawn-qrcode`)
- Create: `app/services/tickets/pdf_renderer.rb`
- Test: `test/services/tickets/pdf_renderer_test.rb`

**Interfaces:**
- Consumes: `Ticket` from Task 3
- Produces: `Tickets::PdfRenderer.new(ticket:).render` returning a PDF byte `String`, and `#filename` returning `"ticket-EB-XXXXXXXXXXXX.pdf"`

- [ ] **Step 1: Add the PDF gems**

In `Gemfile`, directly beneath the existing `gem 'stripe', '~> 10.0'` line, add:

```ruby
# PDF ticket generation with embedded QR codes
gem 'prawn', '~> 2.4'
gem 'prawn-qrcode', '~> 0.5'
```

Run: `bundle install`
Expected: `Bundle complete!` with `prawn` and `prawn-qrcode` resolved

- [ ] **Step 2: Write the failing test**

Create `test/services/tickets/pdf_renderer_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Tickets
  class PdfRendererTest < ActiveSupport::TestCase
    setup { @ticket = tickets(:issued_one) }

    test 'renders a non-trivial PDF document' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render

      assert pdf.start_with?('%PDF'), 'expected a PDF magic header'
      assert_operator pdf.bytesize, :>, 1_000
    end

    test 'embeds the ticket code as searchable text' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render
      text = PDF::Inspector::Text.analyze(pdf).strings.join(' ')

      assert_includes text, @ticket.code
    end

    test 'embeds the event name and tier' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render
      text = PDF::Inspector::Text.analyze(pdf).strings.join(' ')

      assert_includes text, @ticket.event.name
      assert_includes text, @ticket.ticket_type.name
    end

    test 'embeds the holder email and order reference' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render
      text = PDF::Inspector::Text.analyze(pdf).strings.join(' ')

      assert_includes text, @ticket.holder.email
      assert_includes text, @ticket.order.reference
    end

    test 'builds a filename from the code' do
      renderer = Tickets::PdfRenderer.new(ticket: @ticket)
      assert_equal "ticket-#{@ticket.code}.pdf", renderer.filename
    end

    test 'renders even when the event has no venue' do
      @ticket.event.update!(venue: nil)
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render

      assert pdf.start_with?('%PDF')
    end
  end
end
```

- [ ] **Step 3: Add the PDF inspector test dependency**

In `Gemfile`, inside the existing `group :test do` block, add:

```ruby
  gem 'pdf-inspector', '~> 1.3', require: 'pdf/inspector'
```

Run: `bundle install`
Expected: `Bundle complete!`

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/services/tickets/pdf_renderer_test.rb`
Expected: FAIL — `NameError: uninitialized constant Tickets::PdfRenderer`

- [ ] **Step 5: Write the renderer**

Create `app/services/tickets/pdf_renderer.rb`:

```ruby
# frozen_string_literal: true

require 'prawn'
require 'prawn/qrcode'

module Tickets
  # Renders one ticket to a PDF on demand. Nothing is stored: regenerating is
  # cheap and always reflects current event details, so a venue change never
  # leaves a stale PDF in someone's inbox.
  class PdfRenderer
    attr_reader :ticket

    def initialize(ticket:)
      @ticket = ticket
    end

    def filename
      "ticket-#{ticket.code}.pdf"
    end

    def render
      Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
        header(pdf)
        details(pdf)
        qr_section(pdf)
        footer(pdf)
      end.render
    end

    private

    def event
      ticket.event
    end

    def header(pdf)
      pdf.text 'EVENTS BERLIN', size: 10, style: :bold, color: '888888'
      pdf.move_down 6
      pdf.text event.name, size: 24, style: :bold
      pdf.move_down 4
      pdf.text event.date.strftime('%A, %-d %B %Y at %H:%M'), size: 12, color: '444444'
      pdf.move_down 16
      pdf.stroke_horizontal_rule
      pdf.move_down 16
    end

    def details(pdf)
      rows = [
        ['Ticket type', ticket.ticket_type.name],
        ['Location', location_line],
        ['Order', ticket.order.reference],
        ['Issued to', ticket.holder.email]
      ]

      pdf.table(rows, cell_style: { borders: [], padding: [3, 0], size: 11 }) do
        column(0).font_style = :bold
        column(0).width = 110
        column(0).text_color = '666666'
      end

      pdf.move_down 24
    end

    def location_line
      return event.location.to_s if event.venue.nil?

      [event.venue.name, event.venue.address].compact.join(', ')
    end

    def qr_section(pdf)
      pdf.text 'Present this code at the door', size: 10, color: '666666'
      pdf.move_down 10
      pdf.render_qr_code(RQRCode::QRCode.new(ticket.code), level: :h, extent: 160, stroke: false)
      pdf.move_down 10
      pdf.text ticket.code, size: 14, style: :bold
      pdf.move_down 4
      pdf.text 'If the scanner fails, this code can be entered by hand.', size: 8, color: '999999'
    end

    def footer(pdf)
      pdf.move_down 30
      pdf.stroke_horizontal_rule
      pdf.move_down 8
      pdf.text 'This ticket admits one person. It is valid only once.', size: 8, color: '999999'
    end
  end
end
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bin/rails test test/services/tickets/pdf_renderer_test.rb`
Expected: PASS — 6 runs, 0 failures, 0 errors

- [ ] **Step 7: Lint and commit**

```bash
bin/rubocop app/services/tickets/pdf_renderer.rb test/services/tickets/pdf_renderer_test.rb
git add Gemfile Gemfile.lock app/services/tickets/pdf_renderer.rb test/services/tickets/pdf_renderer_test.rb
git commit -m "feat(tickets): render tickets as PDFs with embedded QR codes"
```

---

### Task 13: Email tickets on purchase

**Files:**
- Create: `app/mailers/order_mailer.rb`
- Create: `app/views/order_mailer/confirmation.html.erb`
- Create: `app/views/order_mailer/confirmation.text.erb`
- Create: `app/jobs/order_confirmation_job.rb`
- Modify: `app/services/tickets/issuance_service.rb`
- Delete: `app/mailers/booking_mailer.rb`, `app/views/booking_mailer/`, `app/jobs/booking_confirmation_job.rb`, `test/mailers/booking_mailer_test.rb`
- Test: `test/mailers/order_mailer_test.rb`

**Interfaces:**
- Consumes: `Tickets::PdfRenderer` from Task 12
- Produces: `OrderMailer.confirmation(order)` with one PDF attachment per ticket; `OrderConfirmationJob.perform_later(order_id)`

- [ ] **Step 1: Write the failing test**

Create `test/mailers/order_mailer_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class OrderMailerTest < ActionMailer::TestCase
  setup do
    @order = orders(:paid_one)
    @order.update!(tickets_issued_at: Time.current)
  end

  test 'addresses the buyer' do
    mail = OrderMailer.confirmation(@order)
    assert_equal [@order.user.email], mail.to
  end

  test 'names the event in the subject' do
    mail = OrderMailer.confirmation(@order)
    assert_match(/#{Regexp.escape(@order.event.name)}/, mail.subject)
  end

  test 'attaches one PDF per ticket' do
    mail = OrderMailer.confirmation(@order)
    pdfs = mail.attachments.select { |a| a.content_type.start_with?('application/pdf') }

    assert_equal @order.tickets.count, pdfs.size
  end

  test 'names each attachment after its ticket code' do
    mail = OrderMailer.confirmation(@order)
    names = mail.attachments.map(&:filename)

    @order.tickets.each { |ticket| assert_includes names, "ticket-#{ticket.code}.pdf" }
  end

  test 'body carries the order reference and ticket count' do
    mail = OrderMailer.confirmation(@order)
    body = mail.body.encoded

    assert_match(/#{Regexp.escape(@order.reference)}/, body)
  end

  test 'sends nothing for an order with no tickets' do
    @order.tickets.destroy_all
    mail = OrderMailer.confirmation(@order.reload)

    assert_emails 0 do
      mail.deliver_now
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/mailers/order_mailer_test.rb`
Expected: FAIL — `NameError: uninitialized constant OrderMailer`

- [ ] **Step 3: Write the mailer**

Create `app/mailers/order_mailer.rb`:

```ruby
# frozen_string_literal: true

class OrderMailer < ApplicationMailer
  def confirmation(order)
    @order = order
    @event = order.event
    @tickets = order.tickets.includes(:ticket_type).to_a

    return message.perform_deliveries = false if @tickets.empty?

    attach_tickets

    mail(
      to: order.user.email,
      subject: "Your tickets for #{@event.name}"
    )
  end

  private

  def attach_tickets
    @tickets.each do |ticket|
      renderer = Tickets::PdfRenderer.new(ticket: ticket)
      attachments[renderer.filename] = { mime_type: 'application/pdf', content: renderer.render }
    rescue StandardError => e
      # A single unrenderable ticket must not sink the whole confirmation.
      # The buyer can still download it from their order page.
      Sentry.capture_exception(e) if defined?(Sentry)
    end
  end
end
```

- [ ] **Step 4: Write the HTML view**

Create `app/views/order_mailer/confirmation.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <body style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; color: #1a1a1a; line-height: 1.6;">
    <h1 style="font-size: 22px; margin-bottom: 4px;">You're going to <%= @event.name %></h1>
    <p style="color: #666; margin-top: 0;">
      <%= @event.date.strftime('%A, %-d %B %Y at %H:%M') %>
    </p>

    <p>
      Order <strong><%= @order.reference %></strong> is confirmed.
      <%= pluralize(@tickets.size, 'ticket') %> attached as
      <%= @tickets.size == 1 ? 'a PDF' : 'PDFs' %>.
    </p>

    <table style="border-collapse: collapse; margin: 20px 0;">
      <% @tickets.each do |ticket| %>
        <tr>
          <td style="padding: 6px 16px 6px 0; color: #666;"><%= ticket.ticket_type.name %></td>
          <td style="padding: 6px 0; font-family: monospace;"><%= ticket.code %></td>
        </tr>
      <% end %>
    </table>

    <p>Present the QR code on each ticket at the door. Every ticket admits one person.</p>

    <p style="color: #999; font-size: 12px; margin-top: 32px;">
      Events Berlin — you received this because you bought tickets at <%= @event.name %>.
    </p>
  </body>
</html>
```

- [ ] **Step 5: Write the text view**

Create `app/views/order_mailer/confirmation.text.erb`:

```erb
You're going to <%= @event.name %>
<%= @event.date.strftime('%A, %-d %B %Y at %H:%M') %>

Order <%= @order.reference %> is confirmed.
<%= pluralize(@tickets.size, 'ticket') %> attached.

<% @tickets.each do |ticket| -%>
  <%= ticket.ticket_type.name %> — <%= ticket.code %>
<% end -%>

Present the QR code on each ticket at the door.
Every ticket admits one person.

Events Berlin
```

- [ ] **Step 6: Write the job**

Create `app/jobs/order_confirmation_job.rb`:

```ruby
# frozen_string_literal: true

class OrderConfirmationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return if order.nil? || order.tickets.empty?

    OrderMailer.confirmation(order).deliver_now
  end
end
```

- [ ] **Step 7: Enqueue the job after issuance**

In `app/services/tickets/issuance_service.rb`, replace the `call` method with:

```ruby
    def call
      return { success: true, tickets: order.tickets.to_a } if order.tickets_issued_at.present?
      return failure(:not_paid, 'Tickets are only issued for paid orders') unless order.paid?

      tickets = ActiveRecord::Base.transaction do
        created = order.bookings.flat_map { |booking| issue_for(booking) }
        order.update!(tickets_issued_at: Time.current)
        created
      end

      OrderConfirmationJob.perform_later(order.id)

      { success: true, tickets: tickets }
    end
```

- [ ] **Step 8: Remove the superseded booking mailer**

```bash
git rm -r app/mailers/booking_mailer.rb app/views/booking_mailer app/jobs/booking_confirmation_job.rb test/mailers/booking_mailer_test.rb
```

- [ ] **Step 9: Verify nothing still references it**

Run: `grep -rn "BookingMailer\|BookingConfirmationJob" app/ test/ config/ lib/ || echo "No references remain."`
Expected: `No references remain.`

- [ ] **Step 10: Run the mailer test to verify it passes**

Run: `bin/rails test test/mailers/order_mailer_test.rb`
Expected: PASS — 6 runs, 0 failures, 0 errors

- [ ] **Step 11: Lint and commit**

```bash
bin/rubocop app/mailers/order_mailer.rb app/jobs/order_confirmation_job.rb app/services/tickets/issuance_service.rb test/mailers/order_mailer_test.rb
git add app/mailers/order_mailer.rb app/views/order_mailer app/jobs/order_confirmation_job.rb app/services/tickets/issuance_service.rb test/mailers/order_mailer_test.rb
git commit -m "feat(tickets): email PDF tickets on purchase and retire BookingMailer"
```

---

### Task 14: Ticket serializer and PDF download endpoint

**Files:**
- Create: `app/controllers/api/v1/tickets_controller.rb`
- Create: `app/policies/ticket_policy.rb`
- Create: `app/serializers/ticket_serializer.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/api/v1/tickets_controller_test.rb`

**Interfaces:**
- Consumes: `Tickets::PdfRenderer` from Task 12, `Ticket` from Task 3
- Produces: `GET /api/v1/tickets/:code/download` streaming a PDF; `TicketPolicy` with `#show?`, `#download?`, `#check_in?`; `TicketSerializer` emitting `id`, `code`, `status`, `checked_in_at`, `ticket_type_name`

Tickets are addressed by `code`, not `id`, so a URL from an email is meaningful on its own.

- [ ] **Step 1: Write the failing test**

Create `test/controllers/api/v1/tickets_controller_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class TicketsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @ticket = tickets(:issued_one)  # belongs to bookings(:one) → users(:one)
        @owner = users(:one)
        @stranger = users(:two)
      end

      def auth_headers(user)
        token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        { 'Authorization' => "Bearer #{token}" }
      end

      test 'download requires authentication' do
        get "/api/v1/tickets/#{@ticket.code}/download"
        assert_response :unauthorized
      end

      test 'owner downloads a PDF' do
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@owner)

        assert_response :success
        assert_equal 'application/pdf', response.media_type
        assert response.body.start_with?('%PDF')
      end

      test 'download sets a filename from the code' do
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@owner)
        assert_match(/ticket-#{@ticket.code}\.pdf/, response.headers['Content-Disposition'])
      end

      test 'a stranger cannot download someone elses ticket' do
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@stranger)
        assert_response :forbidden
      end

      test 'an unknown code returns not found' do
        get '/api/v1/tickets/EB-000000000000/download', headers: auth_headers(@owner)
        assert_response :not_found
      end

      test 'a cancelled ticket cannot be downloaded' do
        @ticket.update!(status: 'cancelled', cancelled_at: Time.current)
        get "/api/v1/tickets/#{@ticket.code}/download", headers: auth_headers(@owner)

        assert_response :unprocessable_entity
      end
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/api/v1/tickets_controller_test.rb`
Expected: FAIL — routing error, no route matches `GET /api/v1/tickets/EB-.../download`

- [ ] **Step 3: Add the routes**

In `config/routes.rb`, inside the `namespace :v1` block and directly beneath the `resources :orders` block, add:

```ruby
      resources :tickets, only: [], param: :code do
        member do
          get :download
        end
      end
```

- [ ] **Step 4: Write the policy**

Create `app/policies/ticket_policy.rb`:

```ruby
# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  def show?
    holder? || organiser? || user.admin?
  end

  def download?
    holder? || user.admin?
  end

  # Scanning is the organiser's job, not the attendee's — a holder must never
  # be able to check in their own ticket.
  def check_in?
    organiser? || user.admin?
  end

  def validate?
    check_in?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.joins(:booking).where(bookings: { user_id: user.id })
    end
  end

  private

  def holder?
    record.booking.user_id == user.id
  end

  def organiser?
    record.event.creator_id == user.id
  end
end
```

- [ ] **Step 5: Write the serializer**

Create `app/serializers/ticket_serializer.rb`:

```ruby
# frozen_string_literal: true

class TicketSerializer < ActiveModel::Serializer
  attributes :id, :code, :status, :checked_in_at, :ticket_type_name

  def ticket_type_name
    object.ticket_type.name
  end
end
```

- [ ] **Step 6: Write the controller**

Create `app/controllers/api/v1/tickets_controller.rb`:

```ruby
# frozen_string_literal: true

module Api
  module V1
    class TicketsController < BaseController
      def download
        ticket = find_ticket
        authorize ticket, :download?

        if ticket.cancelled?
          return render json: { error: 'This ticket has been cancelled', code: 'cancelled' },
                        status: :unprocessable_entity
        end

        renderer = Tickets::PdfRenderer.new(ticket: ticket)
        send_data renderer.render,
                  filename: renderer.filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      private

      def find_ticket
        Ticket.includes(:booking, :event, :ticket_type, :holder, :order).find_by!(code: params[:code])
      end
    end
  end
end
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bin/rails test test/controllers/api/v1/tickets_controller_test.rb`
Expected: PASS — 6 runs, 0 failures, 0 errors

- [ ] **Step 8: Lint and commit**

```bash
bin/rubocop app/controllers/api/v1/tickets_controller.rb app/policies/ticket_policy.rb app/serializers/ticket_serializer.rb test/controllers/api/v1/tickets_controller_test.rb
git add app/controllers/api/v1/tickets_controller.rb app/policies/ticket_policy.rb app/serializers/ticket_serializer.rb config/routes.rb test/controllers/api/v1/tickets_controller_test.rb
git commit -m "feat(tickets): add authenticated PDF download by ticket code"
```

---

### Task 15: Order cancellation and refund

**Files:**
- Create: `app/services/orders/cancellation_service.rb`
- Test: `test/services/orders/cancellation_service_test.rb`

**Interfaces:**
- Consumes: `Order` from Task 1, `Event#cancellable?` from Task 4
- Produces: `Orders::CancellationService.new(order:, reason: nil).call` returning `{ success: true, order: Order }` or `{ success: false, error: String, code: Symbol }` with `code` in `%i[not_cancellable past_cutoff refund_failed]`

- [ ] **Step 1: Write the failing test**

Create `test/services/orders/cancellation_service_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Orders
  class CancellationServiceTest < ActiveSupport::TestCase
    setup do
      @order = orders(:paid_one)
      @event = @order.event
      @event.update!(date: 30.days.from_now, cancel_cutoff_hours: 24)
    end

    def stub_refund(id: 're_test_123')
      stub_request(:post, 'https://api.stripe.com/v1/refunds')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { id: id, object: 'refund', status: 'succeeded' }.to_json
        )
    end

    def cancel(reason: 'change_of_plans')
      Orders::CancellationService.new(order: @order, reason: reason).call
    end

    test 'cancels a paid order well before the cutoff' do
      stub_refund
      result = cancel

      assert result[:success], result[:error]
      assert_equal 'cancelled', @order.reload.status
      assert_not_nil @order.cancelled_at
    end

    test 'issues a Stripe refund against the payment intent' do
      stub_refund
      cancel

      assert_requested(:post, 'https://api.stripe.com/v1/refunds') do |req|
        req.body.include?('payment_intent=pi_test_paid_one')
      end
    end

    test 'records the reason' do
      stub_refund
      cancel(reason: 'illness')

      assert_equal 'illness', @order.reload.refund_reason
    end

    test 'cascades bookings and tickets to cancelled' do
      stub_refund
      cancel

      assert(@order.reload.bookings.all? { |b| b.status == 'cancelled' })
      assert(@order.tickets.all?(&:cancelled?))
      assert(@order.tickets.all? { |t| t.cancelled_at.present? })
    end

    test 'releases the inventory it was holding' do
      stub_refund
      before = ticket_types(:one).available_quantity

      cancel

      assert_equal before + 2, ticket_types(:one).reload.available_quantity
    end

    test 'refuses once inside the cutoff window' do
      @event.update!(date: 2.hours.from_now)
      result = cancel

      assert_not result[:success]
      assert_equal :past_cutoff, result[:code]
      assert_equal 'paid', @order.reload.status
    end

    test 'allows cancellation at any time when the event has no cutoff' do
      @event.update!(date: 1.hour.from_now, cancel_cutoff_hours: nil)
      stub_refund

      assert cancel[:success]
    end

    test 'refuses an order that is not paid' do
      @order.update!(status: 'pending', payment_status: 'unpaid')
      result = cancel

      assert_not result[:success]
      assert_equal :not_cancellable, result[:code]
    end

    test 'refuses an already cancelled order' do
      @order.update!(status: 'cancelled')
      result = cancel

      assert_not result[:success]
      assert_equal :not_cancellable, result[:code]
    end

    test 'cancels a free order without calling Stripe' do
      @order.update!(total_amount: 0, stripe_payment_intent_id: nil)
      result = cancel

      assert result[:success], result[:error]
      assert_equal 'cancelled', @order.reload.status
      assert_not_requested :post, 'https://api.stripe.com/v1/refunds'
    end

    test 'leaves the order untouched when the refund fails' do
      stub_request(:post, 'https://api.stripe.com/v1/refunds')
        .to_return(
          status: 400,
          headers: { 'Content-Type' => 'application/json' },
          body: { error: { message: 'charge already refunded', type: 'invalid_request_error' } }.to_json
        )

      result = cancel

      assert_not result[:success]
      assert_equal :refund_failed, result[:code]
      assert_equal 'paid', @order.reload.status
      assert(@order.tickets.none?(&:cancelled?))
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/services/orders/cancellation_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant Orders::CancellationService`

- [ ] **Step 3: Write the service**

Create `app/services/orders/cancellation_service.rb`:

```ruby
# frozen_string_literal: true

module Orders
  # Cancels a paid order and refunds it. The refund is attempted *before* any
  # local state changes, so a Stripe failure leaves the order exactly as it was
  # rather than cancelling tickets the buyer was never refunded for.
  class CancellationService
    attr_reader :order, :reason

    def initialize(order:, reason: nil)
      @order = order
      @reason = reason
    end

    def call
      return failure(:not_cancellable, 'Only paid orders can be cancelled') unless order.paid?
      return failure(:past_cutoff, cutoff_message) unless order.event.cancellable?

      refund_error = issue_refund
      return refund_error if refund_error

      ActiveRecord::Base.transaction do
        order.update!(status: 'cancelled', cancelled_at: Time.current, refund_reason: reason)
        order.bookings.update_all(status: 'cancelled', updated_at: Time.current)
        Ticket.where(booking_id: order.bookings.select(:id))
              .update_all(status: 'cancelled', cancelled_at: Time.current, updated_at: Time.current)
      end

      { success: true, order: order.reload }
    end

    private

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def cutoff_message
      deadline = order.event.cancellable_until
      "Cancellation closed on #{deadline.strftime('%-d %B %Y at %H:%M')}"
    end

    # Returns nil on success, or a failure hash. Free orders have nothing to
    # refund and short-circuit.
    def issue_refund
      return nil if order.free? || order.stripe_payment_intent_id.blank?

      Stripe::Refund.create(payment_intent: order.stripe_payment_intent_id)
      nil
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e) if defined?(Sentry)
      failure(:refund_failed, "We could not process the refund: #{e.message}")
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/services/orders/cancellation_service_test.rb`
Expected: PASS — 11 runs, 0 failures, 0 errors

- [ ] **Step 5: Lint and commit**

```bash
bin/rubocop app/services/orders/cancellation_service.rb test/services/orders/cancellation_service_test.rb
git add app/services/orders/cancellation_service.rb test/services/orders/cancellation_service_test.rb
git commit -m "feat(orders): cancel orders with Stripe refunds behind a per-event cutoff"
```

---

### Task 16: Cancellation endpoint

**Files:**
- Modify: `app/controllers/api/v1/orders_controller.rb`
- Modify: `test/controllers/api/v1/orders_controller_test.rb`

**Interfaces:**
- Consumes: `Orders::CancellationService` from Task 15
- Produces: `DELETE /api/v1/orders/:id` returning the cancelled order or a typed error

The route was already declared in Task 7 (`resources :orders, only: %i[index show destroy]`); this task fills in the action.

- [ ] **Step 1: Write the failing test**

Append these tests inside the existing `OrdersControllerTest` class in `test/controllers/api/v1/orders_controller_test.rb`, directly before the final `end` of the class:

```ruby
      def stub_refund
        stub_request(:post, 'https://api.stripe.com/v1/refunds')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: { id: 're_test_1', object: 'refund', status: 'succeeded' }.to_json
          )
      end

      test 'destroy cancels my paid order' do
        stub_refund
        events(:one).update!(date: 30.days.from_now)

        delete "/api/v1/orders/#{orders(:paid_one).id}",
               params: { reason: 'change_of_plans' },
               headers: auth_headers(@user), as: :json

        assert_response :success
        assert_equal 'cancelled', response.parsed_body['status']
        assert_equal 'cancelled', orders(:paid_one).reload.status
      end

      test 'destroy refuses inside the cutoff window' do
        events(:one).update!(date: 2.hours.from_now, cancel_cutoff_hours: 24)

        delete "/api/v1/orders/#{orders(:paid_one).id}",
               headers: auth_headers(@user), as: :json

        assert_response :unprocessable_entity
        assert_equal 'past_cutoff', response.parsed_body['code']
      end

      test 'destroy forbids cancelling another users order' do
        delete "/api/v1/orders/#{orders(:paid_one).id}",
               headers: auth_headers(@other), as: :json

        assert_response :not_found
        assert_equal 'paid', orders(:paid_one).reload.status
      end

      test 'destroy requires authentication' do
        delete "/api/v1/orders/#{orders(:paid_one).id}", as: :json
        assert_response :unauthorized
      end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/api/v1/orders_controller_test.rb`
Expected: FAIL — `AbstractController::ActionNotFound: The action 'destroy' could not be found`

- [ ] **Step 3: Add the action**

In `app/controllers/api/v1/orders_controller.rb`, add this public action directly after `checkout`:

```ruby
      def destroy
        order = policy_scope(Order).find(params[:id])
        authorize order, :cancel?

        result = Orders::CancellationService.new(order: order, reason: params[:reason]).call

        if result[:success]
          render json: result[:order], serializer: OrderSerializer
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/controllers/api/v1/orders_controller_test.rb`
Expected: PASS — 13 runs, 0 failures, 0 errors

- [ ] **Step 5: Lint and commit**

```bash
bin/rubocop app/controllers/api/v1/orders_controller.rb test/controllers/api/v1/orders_controller_test.rb
git add app/controllers/api/v1/orders_controller.rb test/controllers/api/v1/orders_controller_test.rb
git commit -m "feat(orders): expose order cancellation over the API"
```

---

### Task 17: Check-in state machine

**Files:**
- Create: `app/services/tickets/check_in_service.rb`
- Test: `test/services/tickets/check_in_service_test.rb`

**Interfaces:**
- Consumes: `Ticket` from Task 3
- Produces: `Tickets::CheckInService.new(ticket:, scanned_by:).call` returning `{ success: true, ticket: Ticket }` or `{ success: false, error: String, code: Symbol }` with `code` in `%i[already_checked_in cancelled event_not_started]`

- [ ] **Step 1: Write the failing test**

Create `test/services/tickets/check_in_service_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

module Tickets
  class CheckInServiceTest < ActiveSupport::TestCase
    setup do
      @ticket = tickets(:issued_one)
      @organiser = @ticket.event.creator
      @ticket.event.update!(date: 1.hour.from_now)
    end

    def check_in(ticket: @ticket, by: @organiser)
      Tickets::CheckInService.new(ticket: ticket, scanned_by: by).call
    end

    test 'checks in an issued ticket' do
      freeze_time do
        result = check_in

        assert result[:success], result[:error]
        @ticket.reload
        assert @ticket.checked_in?
        assert_equal Time.current.to_i, @ticket.checked_in_at.to_i
      end
    end

    test 'records who scanned it' do
      check_in
      assert_equal @organiser, @ticket.reload.checked_in_by
    end

    test 'refuses a second scan and reports the original' do
      check_in
      first_time = @ticket.reload.checked_in_at

      travel 10.minutes do
        result = check_in

        assert_not result[:success]
        assert_equal :already_checked_in, result[:code]
        assert_equal first_time.to_i, result[:checked_in_at].to_i
        assert_equal first_time.to_i, @ticket.reload.checked_in_at.to_i
      end
    end

    test 'refuses a cancelled ticket' do
      @ticket.update!(status: 'cancelled', cancelled_at: Time.current)
      result = check_in

      assert_not result[:success]
      assert_equal :cancelled, result[:code]
    end

    test 'refuses a scan long before doors open' do
      @ticket.event.update!(date: 5.days.from_now)
      result = check_in

      assert_not result[:success]
      assert_equal :event_not_started, result[:code]
    end

    test 'allows a scan within the doors-open window' do
      @ticket.event.update!(date: 3.hours.from_now)
      assert check_in[:success]
    end

    test 'allows a scan after the event has begun' do
      @ticket.event.update!(date: 2.hours.ago)
      assert check_in[:success]
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/services/tickets/check_in_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant Tickets::CheckInService`

- [ ] **Step 3: Write the service**

Create `app/services/tickets/check_in_service.rb`:

```ruby
# frozen_string_literal: true

module Tickets
  # Consumes a ticket at the door. The row is locked for the duration so two
  # simultaneous scans of the same code cannot both succeed — exactly one wins
  # and the other is told when the ticket was already used.
  class CheckInService
    # Doors open this far ahead of the advertised start time.
    DOORS_OPEN_BEFORE = 4.hours

    attr_reader :ticket, :scanned_by

    def initialize(ticket:, scanned_by:)
      @ticket = ticket
      @scanned_by = scanned_by
    end

    def call
      ticket.with_lock do
        return failure(:cancelled, 'This ticket has been cancelled') if ticket.cancelled?

        if ticket.checked_in?
          return failure(:already_checked_in, 'This ticket was already used')
            .merge(checked_in_at: ticket.checked_in_at, checked_in_by: ticket.checked_in_by&.email)
        end

        return failure(:event_not_started, "Doors open at #{doors_open_at.strftime('%H:%M on %-d %B')}") unless open?

        ticket.update!(status: 'checked_in', checked_in_at: Time.current, checked_in_by: scanned_by)
      end

      { success: true, ticket: ticket.reload }
    end

    private

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def doors_open_at
      ticket.event.date - DOORS_OPEN_BEFORE
    end

    def open?
      Time.current >= doors_open_at
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/services/tickets/check_in_service_test.rb`
Expected: PASS — 7 runs, 0 failures, 0 errors

- [ ] **Step 5: Lint and commit**

```bash
bin/rubocop app/services/tickets/check_in_service.rb test/services/tickets/check_in_service_test.rb
git add app/services/tickets/check_in_service.rb test/services/tickets/check_in_service_test.rb
git commit -m "feat(tickets): add locked check-in state machine with double-scan protection"
```

---

### Task 18: Check-in endpoints

**Files:**
- Modify: `app/controllers/api/v1/tickets_controller.rb`
- Modify: `config/routes.rb`
- Modify: `test/controllers/api/v1/tickets_controller_test.rb`

**Interfaces:**
- Consumes: `Tickets::CheckInService` from Task 17, `TicketPolicy#check_in?` from Task 14
- Produces: `GET /api/v1/tickets/:code` (organiser preview, non-consuming) and `POST /api/v1/tickets/:code/check_in`

- [ ] **Step 1: Write the failing test**

Append these tests inside the existing `TicketsControllerTest` class in `test/controllers/api/v1/tickets_controller_test.rb`, directly before the final `end` of the class:

```ruby
      test 'organiser previews a ticket without consuming it' do
        organiser = @ticket.event.creator
        get "/api/v1/tickets/#{@ticket.code}", headers: auth_headers(organiser), as: :json

        assert_response :success
        assert_equal @ticket.code, response.parsed_body['code']
        assert_equal 'issued', @ticket.reload.status
      end

      test 'holder cannot preview for check-in' do
        get "/api/v1/tickets/#{@ticket.code}", headers: auth_headers(@owner), as: :json
        assert_response :forbidden
      end

      test 'organiser checks a ticket in' do
        organiser = @ticket.event.creator
        @ticket.event.update!(date: 1.hour.from_now)

        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json

        assert_response :success
        assert_equal 'checked_in', response.parsed_body['status']
        assert @ticket.reload.checked_in?
      end

      test 'a second check-in returns conflict' do
        organiser = @ticket.event.creator
        @ticket.event.update!(date: 1.hour.from_now)

        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json
        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json

        assert_response :conflict
        assert_equal 'already_checked_in', response.parsed_body['code']
      end

      test 'checking in a cancelled ticket is unprocessable' do
        organiser = @ticket.event.creator
        @ticket.event.update!(date: 1.hour.from_now)
        @ticket.update!(status: 'cancelled', cancelled_at: Time.current)

        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(organiser), as: :json

        assert_response :unprocessable_entity
        assert_equal 'cancelled', response.parsed_body['code']
      end

      test 'the holder cannot check in their own ticket' do
        @ticket.event.update!(date: 1.hour.from_now)
        post "/api/v1/tickets/#{@ticket.code}/check_in", headers: auth_headers(@owner), as: :json

        assert_response :forbidden
        assert_equal 'issued', @ticket.reload.status
      end

      test 'an unknown code returns not found on check-in' do
        organiser = @ticket.event.creator
        post '/api/v1/tickets/EB-000000000000/check_in', headers: auth_headers(organiser), as: :json

        assert_response :not_found
      end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/api/v1/tickets_controller_test.rb`
Expected: FAIL — routing error, no route matches `GET /api/v1/tickets/EB-...`

- [ ] **Step 3: Extend the routes**

In `config/routes.rb`, replace the `resources :tickets` block added in Task 14 with:

```ruby
      resources :tickets, only: [:show], param: :code do
        member do
          get :download
          post :check_in
        end
      end
```

- [ ] **Step 4: Add the actions**

In `app/controllers/api/v1/tickets_controller.rb`, add these two public actions directly above the existing `download` action:

```ruby
      def show
        ticket = find_ticket
        authorize ticket, :validate?

        render json: ticket, serializer: TicketSerializer
      end

      def check_in
        ticket = find_ticket
        authorize ticket, :check_in?

        result = Tickets::CheckInService.new(ticket: ticket, scanned_by: current_user).call

        if result[:success]
          render json: result[:ticket], serializer: TicketSerializer
        else
          render json: check_in_error(result), status: status_for(result[:code])
        end
      end
```

And add these private helpers directly beneath the existing private `find_ticket` method:

```ruby
      def check_in_error(result)
        {
          error: result[:error],
          code: result[:code],
          checked_in_at: result[:checked_in_at],
          checked_in_by: result[:checked_in_by]
        }.compact
      end

      def status_for(code)
        code == :already_checked_in ? :conflict : :unprocessable_entity
      end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/controllers/api/v1/tickets_controller_test.rb`
Expected: PASS — 13 runs, 0 failures, 0 errors

- [ ] **Step 6: Lint and commit**

```bash
bin/rubocop app/controllers/api/v1/tickets_controller.rb test/controllers/api/v1/tickets_controller_test.rb
git add app/controllers/api/v1/tickets_controller.rb config/routes.rb test/controllers/api/v1/tickets_controller_test.rb
git commit -m "feat(tickets): add organiser validation and check-in endpoints"
```

---

### Task 19: End-to-end purchase integration test

**Files:**
- Test: `test/integration/ticket_purchase_flow_test.rb`

**Interfaces:**
- Consumes: everything from Tasks 1–18
- Produces: nothing — this task only proves the pieces compose

- [ ] **Step 1: Write the integration test**

Create `test/integration/ticket_purchase_flow_test.rb`:

```ruby
# frozen_string_literal: true

require 'test_helper'

class TicketPurchaseFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @event = events(:one)
    @event.update!(date: 30.days.from_now, cancel_cutoff_hours: 24)
    @ga = ticket_types(:one)
    @vip = ticket_types(:two)
  end

  def auth_headers(user = @user)
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    { 'Authorization' => "Bearer #{token}" }
  end

  def stub_checkout_session
    stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { id: 'cs_flow', url: 'https://checkout.stripe.com/c/pay/cs_flow' }.to_json
      )
  end

  def stub_refund
    stub_request(:post, 'https://api.stripe.com/v1/refunds')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { id: 're_flow', object: 'refund', status: 'succeeded' }.to_json
      )
  end

  def deliver_webhook(order)
    stripe_event = Stripe::Event.construct_from(
      type: 'checkout.session.completed',
      data: {
        object: {
          id: 'cs_flow', object: 'checkout.session',
          payment_intent: 'pi_flow', metadata: { 'order_id' => order.id.to_s }
        }
      }
    )

    Stripe::Webhook.stub(:construct_event, stripe_event) do
      post '/api/v1/checkout/webhook',
           params: '{}',
           headers: { 'HTTP_STRIPE_SIGNATURE' => 't=1,v1=fake', 'CONTENT_TYPE' => 'application/json' }
    end
  end

  test 'buys across two tiers, receives tickets, downloads one, then cancels' do
    stub_checkout_session
    stub_refund

    # 1. Build a cart spanning two tiers
    post "/api/v1/events/#{@event.id}/orders",
         params: { items: [
           { ticket_type_id: @ga.id, quantity: 2 },
           { ticket_type_id: @vip.id, quantity: 1 }
         ] },
         headers: auth_headers, as: :json

    assert_response :created
    order_id = response.parsed_body['id']
    order = Order.find(order_id)
    assert_equal 'pending', order.status
    assert_equal (@ga.price * 2) + @vip.price, order.total_amount

    # 2. Inventory is held while the order is pending
    assert_equal 96, @ga.reload.available_quantity

    # 3. Start checkout
    post "/api/v1/orders/#{order_id}/checkout", headers: auth_headers, as: :json
    assert_response :success
    assert_equal 'https://checkout.stripe.com/c/pay/cs_flow', response.parsed_body['checkout_url']

    # 4. Stripe confirms payment
    perform_enqueued_jobs do
      deliver_webhook(order)
    end
    assert_response :success

    order.reload
    assert_equal 'paid', order.status
    assert_equal 3, order.tickets.count
    assert order.tickets.all?(&:issued?)

    # 5. The buyer got an email with one PDF per ticket
    mail = ActionMailer::Base.deliveries.last
    assert_equal [@user.email], mail.to
    assert_equal 3, mail.attachments.count { |a| a.content_type.start_with?('application/pdf') }

    # 6. Each ticket downloads as a PDF
    ticket = order.tickets.first
    get "/api/v1/tickets/#{ticket.code}/download", headers: auth_headers
    assert_response :success
    assert response.body.start_with?('%PDF')

    # 7. An organiser checks one in
    @event.update!(date: 1.hour.from_now)
    post "/api/v1/tickets/#{ticket.code}/check_in",
         headers: auth_headers(@event.creator), as: :json
    assert_response :success
    assert ticket.reload.checked_in?

    # 8. Cancelling refunds and releases inventory
    @event.update!(date: 30.days.from_now)
    delete "/api/v1/orders/#{order_id}",
           params: { reason: 'change_of_plans' }, headers: auth_headers, as: :json

    assert_response :success
    order.reload
    assert_equal 'cancelled', order.status
    assert order.tickets.all?(&:cancelled?)
    assert_equal 98, @ga.reload.available_quantity
  end

  test 'a free event issues tickets without touching Stripe' do
    free_event = events(:two)
    free_event.update!(date: 30.days.from_now)
    free_tier = TicketType.create!(event: free_event, name: 'Free entry', price: 0, quantity: 50)

    perform_enqueued_jobs do
      post "/api/v1/events/#{free_event.id}/orders",
           params: { items: [{ ticket_type_id: free_tier.id, quantity: 2 }] },
           headers: auth_headers, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'paid', body['status']

    order = Order.find(body['id'])
    assert_equal 2, order.tickets.count
    assert_not_requested :post, 'https://api.stripe.com/v1/checkout/sessions'

    mail = ActionMailer::Base.deliveries.last
    assert_equal 2, mail.attachments.count { |a| a.content_type.start_with?('application/pdf') }
  end

  test 'an abandoned order releases its inventory when it expires' do
    post "/api/v1/events/#{@event.id}/orders",
         params: { items: [{ ticket_type_id: @ga.id, quantity: 10 }] },
         headers: auth_headers, as: :json

    assert_response :created
    assert_equal 88, @ga.reload.available_quantity

    Order.find(response.parsed_body['id']).update!(expires_at: 1.minute.ago)
    OrderExpiryJob.perform_now

    assert_equal 98, @ga.reload.available_quantity
  end
end
```

- [ ] **Step 2: Run the integration test**

Run: `bin/rails test test/integration/ticket_purchase_flow_test.rb`
Expected: PASS — 3 runs, 0 failures, 0 errors

If the mail assertions fail because no mail was delivered, confirm `config/environments/test.rb` sets `config.action_mailer.delivery_method = :test`, and that the test class picks up `ActiveJob::TestHelper` (it is included in `ActionDispatch::IntegrationTest` by default in Rails 7.1).

- [ ] **Step 3: Run the entire suite**

Run: `bin/rails test`
Expected: PASS — every test green. Record the final run count.

- [ ] **Step 4: Commit**

```bash
bin/rubocop test/integration/ticket_purchase_flow_test.rb
git add test/integration/ticket_purchase_flow_test.rb
git commit -m "test: cover the full purchase, check-in, and cancellation journey"
```

---

### Task 20: Admin resources and documentation

**Files:**
- Create: `app/admin/orders.rb`
- Create: `app/admin/tickets.rb`
- Modify: `app/admin/bookings.rb`
- Modify: `documentation/API_DOCUMENTATION.md`
- Modify: `documentation/ARCHITECTURE.md`

**Interfaces:**
- Consumes: `Order` and `Ticket` from Tasks 1 and 3
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Register the Order admin resource**

Create `app/admin/orders.rb`:

```ruby
# frozen_string_literal: true

ActiveAdmin.register Order do
  permit_params :status, :payment_status, :refund_reason

  filter :status, as: :select, collection: Order::STATUSES
  filter :payment_status, as: :select, collection: Order::PAYMENT_STATUSES
  filter :event
  filter :user
  filter :created_at

  index do
    selectable_column
    id_column
    column(:reference) { |order| order.reference }
    column :user
    column :event
    column :status
    column :payment_status
    column :total_amount
    column(:tickets) { |order| order.tickets.count }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :reference
      row :user
      row :event
      row :status
      row :payment_status
      row :total_amount
      row :currency
      row :stripe_checkout_session_id
      row :stripe_payment_intent_id
      row :expires_at
      row :paid_at
      row :tickets_issued_at
      row :cancelled_at
      row :refunded_at
      row :refund_reason
      row :created_at
    end

    panel 'Line items' do
      table_for order.bookings do
        column(:ticket_type) { |booking| booking.ticket_type.name }
        column :quantity
        column :total_price
        column :status
      end
    end

    panel 'Tickets' do
      table_for order.tickets do
        column :code
        column :status
        column :checked_in_at
        column :checked_in_by
      end
    end
  end
end
```

- [ ] **Step 2: Register the Ticket admin resource**

Create `app/admin/tickets.rb`:

```ruby
# frozen_string_literal: true

ActiveAdmin.register Ticket do
  actions :index, :show

  filter :code
  filter :status, as: :select, collection: Ticket::STATUSES
  filter :checked_in_at
  filter :created_at

  index do
    selectable_column
    id_column
    column :code
    column(:event) { |ticket| ticket.event.name }
    column(:holder) { |ticket| ticket.holder.email }
    column(:ticket_type) { |ticket| ticket.ticket_type.name }
    column :status
    column :checked_in_at
    actions
  end

  show do
    attributes_table do
      row :code
      row :status
      row(:event) { |ticket| ticket.event.name }
      row(:holder) { |ticket| ticket.holder.email }
      row(:order) { |ticket| ticket.order.reference }
      row :checked_in_at
      row :checked_in_by
      row :cancelled_at
      row :created_at
    end
  end
end
```

- [ ] **Step 3: Show the parent order on the Booking admin page**

In `app/admin/bookings.rb`, add this line to the `index do` block directly after `id_column`:

```ruby
    column(:order) { |booking| booking.order&.reference }
```

And add this line to the `attributes_table` inside the `show do` block, directly after `row :id`:

```ruby
      row(:order) { |booking| booking.order&.reference }
```

- [ ] **Step 4: Verify the admin panel boots**

Run: `bin/rails runner 'ActiveAdmin.application.namespaces[:admin].resources.each { |r| puts r.resource_name }'`
Expected: output includes `Order`, `Ticket`, and `Booking` with no exceptions

- [ ] **Step 5: Document the new endpoints**

In `documentation/API_DOCUMENTATION.md`, add this section at the end of the file:

```markdown
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

`invalid_items`, `sold_out`, `cap_exceeded`, `event_past`, `not_payable`,
`not_cancellable`, `past_cutoff`, `refund_failed`

## Tickets

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/tickets/:code` | Organiser | Validate a ticket without consuming it. |
| `GET` | `/api/v1/tickets/:code/download` | Holder | Download the ticket as a PDF with an embedded QR code. |
| `POST` | `/api/v1/tickets/:code/check_in` | Organiser | Consume the ticket at the door. Returns `409` if already used. |

Ticket codes are `EB-` followed by 12 Crockford base32 characters, e.g. `EB-A7X9K2M4P8Q3`.
The QR encodes the bare code, so any scanner can read it offline.
```

- [ ] **Step 6: Document the domain model**

In `documentation/ARCHITECTURE.md`, add this section at the end of the file:

```markdown
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

`Order.holding_inventory` is the single source of truth: an order holds stock while it is
`paid`, or `pending` and not yet past `expires_at`. `TicketType#available_quantity` and
`Event#available_capacity` both derive from it, so an abandoned cart releases its stock
automatically when the hold lapses — no cleanup job is required for correctness.

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
```

- [ ] **Step 7: Run the full suite one final time**

Run: `bin/rails test`
Expected: PASS — all green

- [ ] **Step 8: Lint everything and commit**

```bash
bin/rubocop
git add app/admin documentation/
git commit -m "feat(admin): add Order and Ticket admin resources and document the ticketing domain"
```

---

## What this plan does not cover

These are deliberately deferred to follow-up plans, per the source spec:

- **Frontend** (spec phase 6) — ticket picker, orders list and detail, checkout polish, cancel modal. Plan 2.
- **Waitlist** (spec phase 7) — `waitlist_entries`, promotion and claim services, offer mailer, expiry job. Plan 3.
- **Column cleanup** (spec phase 8) — dropping `stripe_checkout_session_id`, `stripe_payment_intent_id`, `payment_status`, and `paid_at` from `bookings` once the new code has run in production. Plan 3.

## Known breakage between Plan 1 and Plan 2

A `Booking` cannot exist without an `Order` after Task 2, so the booking-scoped purchase endpoints are removed in that task rather than left returning 422:

- `POST /api/v1/events/:event_id/bookings` — replaced by `POST /api/v1/events/:event_id/orders`
- `POST /api/v1/checkout/sessions` — replaced by `POST /api/v1/orders/:id/checkout`

`GET /api/v1/bookings`, `GET /api/v1/bookings/:id`, and `PATCH /api/v1/bookings/:id/cancel` remain routed and working.

The existing frontend calls both removed endpoints from `frontend/src/services/bookingService.ts`, so **the frontend purchase flow is non-functional for the duration of this plan**. Plan 2 rebuilds it against orders. This is a deliberate trade: carrying a shim that maps the old single-booking shape onto orders would mean building and testing a code path that Plan 2 deletes.
