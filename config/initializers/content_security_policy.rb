# frozen_string_literal: true

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, 'res.cloudinary.com'
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, 'wss:'

    if Rails.env.development?
      policy.script_src(*policy.script_src, :unsafe_eval)
      policy.connect_src(*policy.connect_src, 'http://localhost:3001', 'ws://localhost:3001')
    end

    policy.report_uri '/csp-violation-report'
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_report_only = Rails.env.development?
end
