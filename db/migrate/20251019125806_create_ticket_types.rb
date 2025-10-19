class CreateTicketTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_types do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false, default: 0
      t.integer :quantity, null: false, default: 0
      t.text :description

      t.timestamps
    end

    add_index :ticket_types, %i[event_id name]
  end
end
