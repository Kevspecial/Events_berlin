# frozen_string_literal: true

Rails.application.configure do
  config.permissions_policy do |f|
    f.camera      :none
    f.geolocation :none
    f.microphone  :none
    f.payment     :self
    f.usb         :none
  end
end
