# frozen_string_literal: true

class AddStripeFieldsToBookings < ActiveRecord::Migration[7.1]
  def change
    add_column :bookings, :stripe_checkout_session_id, :string
    add_column :bookings, :stripe_payment_intent_id, :string
    add_column :bookings, :payment_status, :string, default: 'unpaid'
    add_column :bookings, :paid_at, :datetime

    add_index :bookings, :stripe_checkout_session_id, unique: true
    add_index :bookings, :stripe_payment_intent_id
  end
end
