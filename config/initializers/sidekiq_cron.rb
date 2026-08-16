# frozen_string_literal: true

# Only the Sidekiq process should load the schedule; the web process would
# otherwise register duplicate entries on every boot.
if defined?(Sidekiq::Cron) && Sidekiq.server?
  Sidekiq::Cron::Job.create(
    name: 'Expire abandoned orders',
    cron: '* * * * *',
    class: 'OrderExpiryJob'
  )
end
