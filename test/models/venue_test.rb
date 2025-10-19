require 'test_helper'

class VenueTest < ActiveSupport::TestCase
  test 'valid venue' do
    venue = Venue.new(name: 'Berlin Arena', address: 'Main St 123', city: 'Berlin')
    assert venue.valid?
  end

  test 'requires name' do
    venue = Venue.new(address: 'Main St', city: 'Berlin')
    assert_not venue.valid?
    assert_includes venue.errors[:name], "can't be blank"
  end

  test 'requires address' do
    venue = Venue.new(name: 'Arena', city: 'Berlin')
    assert_not venue.valid?
    assert_includes venue.errors[:address], "can't be blank"
  end

  test 'requires city' do
    venue = Venue.new(name: 'Arena', address: 'Main St')
    assert_not venue.valid?
    assert_includes venue.errors[:city], "can't be blank"
  end
end
