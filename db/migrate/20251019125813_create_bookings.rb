class CreateBookings < ActiveRecord::Migration[7.1]
  def change
    create_table :bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.references :ticket_type, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: 'pending'

      t.timestamps
    end

    add_index :bookings, %i[user_id event_id]
    add_index :bookings, :status
  end
end
