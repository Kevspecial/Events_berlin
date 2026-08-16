# frozen_string_literal: true

class AddTicketsIssuedAtToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :tickets_issued_at, :datetime
  end
end
