ActiveAdmin.register User do
  # Permit parameters for forms
  permit_params :email, :password, :password_confirmation, :role

  # Index page configuration
  index do
    selectable_column
    id_column
    column :email
    column :role
    column :created_at
    column "Last Sign In" do |user|
      user.remember_created_at&.strftime("%B %d, %Y at %I:%M %p") || "Never"
    end
    actions
  end

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :email
      row :role
      row :created_at
      row :updated_at
      row "Last Remember" do |user|
        user.remember_created_at&.strftime("%B %d, %Y at %I:%M %p") || "Never"
      end
    end

    panel 'Created Events' do
      table_for user.created_events do
        column :id
        column :name
        column :location
        column :date
        column :price
        column 'Actions' do |event|
          link_to 'View', admin_event_path(event)
        end
      end
    end

    panel 'Attended Events' do
      table_for user.attended_events do
        column :id
        column :name
        column :location
        column :date
        column 'Actions' do |event|
          link_to 'View', admin_event_path(event)
        end
      end
    end

    panel 'Bookings' do
      table_for user.bookings do
        column :id
        column :event
        column :total_price
        column :status
        column :created_at
        column 'Actions' do |booking|
          link_to 'View', admin_booking_path(booking)
        end
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs do
      f.input :email
      f.input :role, as: :select, collection: User.roles.keys.map { |role| [role.humanize, role] }
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

  # Filters for search
  filter :email
  filter :role, as: :select, collection: User.roles.keys.map { |role| [role.humanize, role] }
  filter :created_at
end
