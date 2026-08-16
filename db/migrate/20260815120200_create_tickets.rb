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
