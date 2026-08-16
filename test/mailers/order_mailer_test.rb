# frozen_string_literal: true

require 'test_helper'

class OrderMailerTest < ActionMailer::TestCase
  setup do
    @order = orders(:paid_one)
    @order.update!(tickets_issued_at: Time.current)
  end

  test 'addresses the buyer' do
    mail = OrderMailer.confirmation(@order)
    assert_equal [@order.user.email], mail.to
  end

  test 'names the event in the subject' do
    mail = OrderMailer.confirmation(@order)
    assert_match(/#{Regexp.escape(@order.event.name)}/, mail.subject)
  end

  test 'attaches one PDF per ticket' do
    mail = OrderMailer.confirmation(@order)
    pdfs = mail.attachments.select { |a| a.content_type.start_with?('application/pdf') }

    assert_equal @order.tickets.count, pdfs.size
  end

  test 'names each attachment after its ticket code' do
    mail = OrderMailer.confirmation(@order)
    names = mail.attachments.map(&:filename)

    @order.tickets.each { |ticket| assert_includes names, "ticket-#{ticket.code}.pdf" }
  end

  test 'body carries the order reference and ticket count' do
    mail = OrderMailer.confirmation(@order)
    body = mail.body.encoded

    assert_match(/#{Regexp.escape(@order.reference)}/, body)
  end

  test 'sends nothing for an order with no tickets' do
    @order.bookings.each { |booking| booking.tickets.destroy_all }
    mail = OrderMailer.confirmation(@order.reload)

    assert_emails 0 do
      mail.deliver_now
    end
  end
end
