# frozen_string_literal: true

require 'test_helper'

module Tickets
  class PdfRendererTest < ActiveSupport::TestCase
    setup { @ticket = tickets(:issued_one) }

    test 'renders a non-trivial PDF document' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render

      assert pdf.start_with?('%PDF'), 'expected a PDF magic header'
      assert_operator pdf.bytesize, :>, 1_000
    end

    test 'embeds the ticket code as searchable text' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render
      text = PDF::Inspector::Text.analyze(pdf).strings.join(' ')

      assert_includes text, @ticket.code
    end

    test 'embeds the event name and tier' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render
      text = PDF::Inspector::Text.analyze(pdf).strings.join(' ')

      assert_includes text, @ticket.event.name
      assert_includes text, @ticket.ticket_type.name
    end

    test 'embeds the holder email and order reference' do
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render
      text = PDF::Inspector::Text.analyze(pdf).strings.join(' ')

      assert_includes text, @ticket.holder.email
      assert_includes text, @ticket.order.reference
    end

    test 'builds a filename from the code' do
      renderer = Tickets::PdfRenderer.new(ticket: @ticket)
      assert_equal "ticket-#{@ticket.code}.pdf", renderer.filename
    end

    test 'renders even when the event has no venue' do
      @ticket.event.update!(venue: nil)
      pdf = Tickets::PdfRenderer.new(ticket: @ticket).render

      assert pdf.start_with?('%PDF')
    end
  end
end
