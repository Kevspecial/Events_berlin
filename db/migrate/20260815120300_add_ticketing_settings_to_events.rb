# frozen_string_literal: true

class AddTicketingSettingsToEvents < ActiveRecord::Migration[7.1]
  def change
    change_table :events, bulk: true do |t|
      t.column :cancel_cutoff_hours, :integer, default: 24
      t.column :max_tickets_per_order, :integer, default: 10
    end
  end
end
