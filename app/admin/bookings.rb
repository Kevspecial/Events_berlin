ActiveAdmin.register Booking do
  # Permit parameters for forms
  permit_params :user_id, :event_id, :ticket_type_id, :quantity, :status

  # Index page configuration
  index do
    selectable_column
    id_column
    column :user
    column :event
    column :ticket_type
    column :quantity
    column :total_price
    column :status
    column :created_at
    actions
  end

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :user
      row :event
      row :ticket_type
      row :quantity
      row :total_price
      row :status
      row :created_at
      row :updated_at
    end
  end

  # Form configuration
  form do |f|
    f.inputs do
      f.input :user, as: :select, collection: User.all.collect { |u|
        ["#{u.email} (#{u.role.humanize})", u.id]
      }
      f.input :event, as: :select, collection: Event.all.collect { |e| [e.name, e.id] }
      f.input :ticket_type, as: :select, collection: TicketType.all.collect { |t| ["#{t.name} - $#{t.price}", t.id] }
      f.input :quantity
      f.input :status, as: :select, collection: %w[pending confirmed cancelled]
    end
    f.actions
  end

  # Filters for search
  filter :user
  filter :event
  filter :ticket_type
  filter :status, as: :select, collection: %w[pending confirmed cancelled]
  filter :total_price
  filter :created_at
end
