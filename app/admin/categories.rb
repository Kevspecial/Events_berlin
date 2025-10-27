ActiveAdmin.register Category do
  # Permit parameters for forms
  permit_params :name, :description

  # Index page configuration
  index do
    selectable_column
    id_column
    column :name
    column :description
    column 'Events Count' do |category|
      category.events.count
    end
    column :created_at
    actions
  end

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :created_at
      row :updated_at
    end

    panel 'Events in this Category' do
      table_for category.events do
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
  end

  # Form configuration
  form do |f|
    f.inputs do
      f.input :name
      f.input :description
    end
    f.actions
  end

  # Filters for search
  filter :name
  filter :description
  filter :created_at
end
