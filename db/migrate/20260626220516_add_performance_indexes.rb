class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :events, :date unless index_exists?(:events, :date)
    add_index :events, :private unless index_exists?(:events, :private)
    add_index :bookings, :payment_status unless index_exists?(:bookings, :payment_status)
  end
end
