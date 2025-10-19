class AddFieldsToEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :events, :category, foreign_key: true
    add_reference :events, :venue, foreign_key: true
    add_column :events, :price, :decimal, precision: 10, scale: 2
    add_column :events, :capacity, :integer
  end
end
