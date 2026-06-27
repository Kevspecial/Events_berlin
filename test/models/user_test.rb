# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'valid user saves successfully' do
    user = User.new(email: 'valid@example.com', password: 'password123', role: :attendee)
    assert user.valid?
  end

  test 'requires email' do
    user = User.new(password: 'password123')
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test 'requires unique email' do
    existing = users(:one)
    user = User.new(email: existing.email, password: 'password123')
    assert_not user.valid?
  end

  test 'cannot assign admin role on create' do
    user = User.new(email: 'newadmin@example.com', password: 'password123', role: :admin)
    assert_not user.valid?
    assert_includes user.errors[:role], 'cannot be set to admin'
  end

  test 'can bypass admin validation with skip flag' do
    user = User.new(email: 'seededadmin@example.com', password: 'password123', role: :admin)
    user.skip_admin_validation = true
    assert user.valid?
  end

  test 'organizer role is allowed on create' do
    user = User.new(email: 'organizer@example.com', password: 'password123', role: :organizer)
    assert user.valid?
  end
end
