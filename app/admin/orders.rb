# frozen_string_literal: true

ActiveAdmin.register Order do
  permit_params :status, :payment_status, :refund_reason

  filter :status, as: :select, collection: Order::STATUSES
  filter :payment_status, as: :select, collection: Order::PAYMENT_STATUSES
  filter :event
  filter :user
  filter :created_at

  index do
    selectable_column
    id_column
    column(:reference, &:reference)
    column :user
    column :event
    column :status
    column :payment_status
    column :total_amount
    column(:tickets) { |order| order.tickets.count }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :reference
      row :user
      row :event
      row :status
      row :payment_status
      row :total_amount
      row :currency
      row :stripe_checkout_session_id
      row :stripe_payment_intent_id
      row :expires_at
      row :paid_at
      row :tickets_issued_at
      row :cancelled_at
      row :refunded_at
      row :refund_reason
      row :created_at
    end

    panel 'Line items' do
      table_for order.bookings do
        column(:ticket_type) { |booking| booking.ticket_type.name }
        column :quantity
        column :total_price
        column :status
      end
    end

    panel 'Tickets' do
      table_for order.tickets do
        column :code
        column :status
        column :checked_in_at
        column :checked_in_by
      end
    end
  end
end
