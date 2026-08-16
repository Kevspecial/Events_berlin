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
