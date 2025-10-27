ActiveAdmin.register Venue do
  # Permit parameters for forms
  permit_params :name, :address, :capacity, :description

  # Index page configuration
  index do
    selectable_column
    id_column
    column :name
    column :address
    column :capacity
    column 'Events Count' do |venue|
      venue.events.count
    end
    column :created_at
    actions
  end

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :name
      row :address
      row :capacity
      row :description
      row :created_at
      row :updated_at
    end

    panel 'Events at this Venue' do
      table_for venue.events do
        column :id
        column :name
        column :date
        column :price
        column :capacity
        column 'Actions' do |event|
          link_to 'View', admin_event_path(event)
        end
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs do
      f.input :name
      f.input :address
      f.input :capacity
      f.input :description
    end
    f.actions
  end

  # Filters for search
  filter :name
  filter :address
  filter :capacity
  filter :created_at
end
