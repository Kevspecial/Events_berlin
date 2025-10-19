ActiveAdmin.register Event do
  # Permit parameters for forms
  permit_params :name, :description, :location, :date, :private, :creator_id, :category_id, :venue_id, :price,
                :capacity, :image

  # Index page configuration
  index do
    selectable_column
    id_column
    column :name
    column :location
    column :date
    column :price
    column :capacity
    column :private
    column :creator
    column :category
    column :venue
    column :created_at
    actions
  end

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :location
      row :date
      row :price
      row :capacity
      row :private
      row :creator
      row :category
      row :venue
      row :image do |event|
        if event.image.attached?
          image_tag url_for(event.image), style: 'max-width: 300px;'
        else
          'No image'
        end
      end
      row :created_at
      row :updated_at
    end

    panel 'Attendees' do
      table_for event.attendees do
        column :id
        column :email
        column :role
      end
    end

    panel 'Bookings' do
      table_for event.bookings do
        column :id
        column :user
        column :total_price
        column :status
        column :created_at
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs do
      f.input :name
      f.input :description
      f.input :location
      f.input :date, as: :datetime_local
      f.input :price
      f.input :capacity
      f.input :private
      f.input :creator, as: :select, collection: User.all.collect { |u|
        ["#{u.email} (#{u.role.humanize})", u.id]
      }
      f.input :category, as: :select, collection: Category.all.collect { |c| [c.name, c.id] }, include_blank: true
      f.input :venue, as: :select, collection: Venue.all.collect { |v| [v.name, v.id] }, include_blank: true
      f.input :image, as: :file
    end
    f.actions
  end

  # Filters for search
  filter :name
  filter :location
  filter :date
  filter :price
  filter :capacity
  filter :private
  filter :creator
  filter :category
  filter :venue
  filter :created_at
end
