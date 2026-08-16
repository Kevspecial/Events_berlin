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
