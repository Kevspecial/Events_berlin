# frozen_string_literal: true

ActiveAdmin.register Ticket do
  actions :index, :show

  filter :code
  filter :status, as: :select, collection: Ticket::STATUSES
  filter :checked_in_at
  filter :created_at

  index do
    selectable_column
    id_column
    column :code
    column(:event) { |ticket| ticket.event.name }
    column(:holder) { |ticket| ticket.holder.email }
    column(:ticket_type) { |ticket| ticket.ticket_type.name }
    column :status
    column :checked_in_at
    actions
  end

  show do
    attributes_table do
      row :code
      row :status
      row(:event) { |ticket| ticket.event.name }
      row(:holder) { |ticket| ticket.holder.email }
      row(:order) { |ticket| ticket.order.reference }
      row :checked_in_at
      row :checked_in_by
      row :cancelled_at
      row :created_at
    end
  end
end
