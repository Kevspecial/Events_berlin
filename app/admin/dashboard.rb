# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do
    # Statistics panel
    columns do
      column do
        panel 'Statistics' do
          div do
            h3 "Total Events: #{Event.count}"
            h3 "Total Users: #{User.count}"
            h3 "Total Bookings: #{Booking.count}"
            h3 "Total Revenue: $#{Booking.sum(:total_price)}"
          end
        end
      end

      column do
        panel 'User Roles' do
          div do
            User.roles.each do |role, value|
              h4 "#{role.humanize}: #{User.where(role: value).count}"
            end
          end
        end
      end
    end

    columns do
      column do
        panel 'Recent Events' do
          table do
            thead do
              tr do
                th 'Name'
                th 'Date'
                th 'Location'
                th 'Price'
                th 'Actions'
              end
            end
            tbody do
              Event.order(created_at: :desc).limit(5).each do |event|
                tr do
                  td link_to(event.name, admin_event_path(event))
                  td event.date.strftime('%B %d, %Y')
                  td event.location
                  td event.price ? "$#{event.price}" : 'Free'
                  td link_to('View', admin_event_path(event), class: 'button')
                end
              end
            end
          end
        end
      end

      column do
        panel 'Recent Users' do
          table do
            thead do
              tr do
                th 'Email'
                th 'Name'
                th 'Role'
                th 'Joined'
                th 'Actions'
              end
            end
            tbody do
              User.order(created_at: :desc).limit(5).each do |user|
                tr do
                  td link_to(user.email, admin_user_path(user))
                  td user.email.split('@').first.humanize # Use email prefix as name
                  td user.role.humanize
                  td user.created_at.strftime('%B %d, %Y')
                  td link_to('View', admin_user_path(user), class: 'button')
                end
              end
            end
          end
        end
      end
    end

    columns do
      column do
        panel 'Recent Bookings' do
          table do
            thead do
              tr do
                th 'User'
                th 'Event'
                th 'Amount'
                th 'Status'
                th 'Date'
                th 'Actions'
              end
            end
            tbody do
              Booking.order(created_at: :desc).limit(5).each do |booking|
                tr do
                  td link_to(booking.user.email, admin_user_path(booking.user))
                  td link_to(booking.event.name, admin_event_path(booking.event))
                  td "$#{booking.total_price}"
                  td status_tag(booking.status)
                  td booking.created_at.strftime('%B %d, %Y')
                  td link_to('View', admin_booking_path(booking), class: 'button')
                end
              end
            end
          end
        end
      end
    end
    # end
  end # content
end
