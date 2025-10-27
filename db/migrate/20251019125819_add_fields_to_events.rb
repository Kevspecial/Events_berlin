class AddFieldsToEvents < ActiveRecord::Migration[7.1]
  def change
    change_table :events, bulk: true do |t|
      t.references :category, foreign_key: true
      t.references :venue, foreign_key: true
      t.decimal :price, precision: 10, scale: 2
      t.integer :capacity
    end
  end
end
