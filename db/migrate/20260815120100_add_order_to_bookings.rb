# frozen_string_literal: true

class AddOrderToBookings < ActiveRecord::Migration[7.1]
  def up
    add_reference :bookings, :order, foreign_key: true, null: true, index: true

    # Permanent provenance marker, not a temporary scratch column. It pairs
    # each backfilled order back to the booking it came from: (user_id,
    # event_id, created_at) is not unique, so matching on those columns can
    # silently mispair or duplicate-pair bookings when a user has two
    # bookings for the same event created at the same timestamp. Carrying
    # the source booking id through the insert makes the pairing
    # deterministic. It is kept (not dropped) after use because a non-null
    # value means this order is a synthetic wrapper created by this backfill
    # rather than a real customer purchase -- that is what lets `down` tell
    # backfilled orders apart from application-created ones and roll back
    # safely, and it lets later reporting exclude synthetic orders from
    # revenue figures.
    add_column :orders, :backfill_booking_id, :bigint

    # Wrap every pre-existing booking in a single-line shim order so no
    # historical row is lost. Uses raw SQL so it never depends on model code.
    #
    # orders.stripe_payment_intent_id and orders.stripe_checkout_session_id
    # each carry a UNIQUE index, but bookings only has non-unique indexes on
    # their equivalents. Two bookings that shared one Stripe payment (a
    # grouped checkout) would otherwise produce two orders with the same
    # value and abort the migration. Keep the value on only the first
    # booking of each group (by id) and null it out for the rest -- NULLs
    # don't conflict under a Postgres unique index, and no data is lost
    # because bookings retains its own copies of both columns until a later
    # cleanup plan drops them.
    execute <<~SQL.squish
      INSERT INTO orders (
        user_id, event_id, status, total_amount, currency,
        stripe_checkout_session_id, stripe_payment_intent_id, payment_status,
        expires_at, paid_at, created_at, updated_at, backfill_booking_id
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
        CASE WHEN ROW_NUMBER() OVER (
          PARTITION BY b.stripe_checkout_session_id ORDER BY b.id
        ) = 1 THEN b.stripe_checkout_session_id ELSE NULL END,
        CASE WHEN ROW_NUMBER() OVER (
          PARTITION BY b.stripe_payment_intent_id ORDER BY b.id
        ) = 1 THEN b.stripe_payment_intent_id ELSE NULL END,
        COALESCE(b.payment_status, 'unpaid'),
        b.created_at + INTERVAL '15 minutes',
        b.paid_at,
        b.created_at,
        b.updated_at,
        b.id
      FROM bookings b
      WHERE b.order_id IS NULL
    SQL

    # Pair each booking with the order just created for it by the source
    # booking id carried through above -- deterministic, unlike matching on
    # (user_id, event_id, created_at).
    execute <<~SQL.squish
      UPDATE bookings b
      SET order_id = o.id
      FROM orders o
      WHERE o.backfill_booking_id = b.id
    SQL

    add_index :orders, :backfill_booking_id

    change_column_null :bookings, :order_id, false
  end

  def down
    # Orders created by the application have no backfill marker. Rolling back
    # would delete them along with the synthetic ones, so refuse instead of
    # guessing. The lock closes the window between counting and deleting.
    ActiveRecord::Base.transaction do
      execute 'LOCK TABLE orders IN EXCLUSIVE MODE'

      real_orders = select_value('SELECT COUNT(*) FROM orders WHERE backfill_booking_id IS NULL').to_i

      if real_orders.positive?
        raise ActiveRecord::IrreversibleMigration,
              "Refusing to roll back: #{real_orders} order(s) were created by the " \
              'application, not by this backfill. Rolling back would destroy them.'
      end

      execute 'DELETE FROM orders WHERE backfill_booking_id IS NOT NULL'
      remove_reference :bookings, :order, foreign_key: true
    end
  end
end
