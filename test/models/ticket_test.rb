# frozen_string_literal: true

require 'test_helper'

class TicketTest < ActiveSupport::TestCase
  test 'generates a code with the EB prefix and twelve base32 characters' do
    code = Ticket.generate_code
    assert_match(/\AEB-[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{12}\z/, code)
  end

  test 'generated codes exclude ambiguous glyphs' do
    200.times do
      body = Ticket.generate_code.delete_prefix('EB-')
      assert_no_match(/[ILOU]/, body)
    end
  end

  test 'assigns a code automatically on create' do
    ticket = Ticket.create!(booking: bookings(:one))
    assert_match(/\AEB-/, ticket.code)
    assert_equal 'issued', ticket.status
  end

  test 'enforces code uniqueness' do
    existing = tickets(:issued_one)
    duplicate = Ticket.new(booking: bookings(:one), code: existing.code)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], 'has already been taken'
  end

  test 'rejects an unknown status' do
    ticket = Ticket.new(booking: bookings(:one), status: 'banana')
    assert_not ticket.valid?
  end

  test 'status predicates reflect the status column' do
    assert tickets(:issued_one).issued?
    assert tickets(:checked_in_one).checked_in?
    assert tickets(:cancelled_one).cancelled?
  end

  test 'exposes event and holder through its booking' do
    ticket = tickets(:issued_one)
    assert_equal events(:one), ticket.event
    assert_equal users(:one), ticket.holder
  end

  test 'scopes filter by status' do
    assert_includes Ticket.issued, tickets(:issued_one)
    assert_not_includes Ticket.issued, tickets(:cancelled_one)
  end
end
