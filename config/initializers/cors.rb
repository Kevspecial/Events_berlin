Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow CORS from configured origins (comma-separated), fallback to common dev ports
    origins(*ENV.fetch('CORS_ORIGINS', 'http://localhost:3001,http://localhost:3000,http://localhost:5173').split(','))
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head]
  end
end

# This configuration allows CORS requests from the specified origins
# and permits all headers and methods for the resources.
