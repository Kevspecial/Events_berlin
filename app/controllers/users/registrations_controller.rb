# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    private

    # Force role to attendee for any signup coming through Devise registrations
    # This ensures clients cannot assign elevated roles via the signup form.
    def sign_up_params
      params.require(:user).permit(:email, :password, :password_confirmation).merge(role: :attendee)
    end
  end
end
