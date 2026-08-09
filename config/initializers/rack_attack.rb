# frozen_string_literal: true

class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  )

  throttle('login/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/login' && req.post?
      req.ip
    end
  end

  throttle('login/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/login' && req.post?
      req.params['email']&.downcase&.gsub(/\s+/, '')
    end
  end

  throttle('signup/ip', limit: 3, period: 1.minute) do |req|
    if req.path == '/api/v1/signup' && req.post?
      req.ip
    end
  end

  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  self.throttled_responder = lambda do |_env|
    [
      429,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Too many requests. Please try again later.' }.to_json]
    ]
  end
end
