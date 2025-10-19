class CreateVenues < ActiveRecord::Migration[7.1]
  def change
    create_table :venues do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.string :city, null: false
      t.integer :capacity

      t.timestamps
    end
    
    add_index :venues, [:name, :city]
  end
end
