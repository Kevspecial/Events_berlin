# frozen_string_literal: true

require 'prawn'
require 'prawn/qrcode'

module Tickets
  # Renders one ticket to a PDF on demand. Nothing is stored: regenerating is
  # cheap and always reflects current event details, so a venue change never
  # leaves a stale PDF in someone's inbox.
  class PdfRenderer
    attr_reader :ticket

    def initialize(ticket:)
      @ticket = ticket
    end

    def filename
      "ticket-#{ticket.code}.pdf"
    end

    def render
      Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
        header(pdf)
        details(pdf)
        qr_section(pdf)
        footer(pdf)
      end.render
    end

    private

    def event
      ticket.event
    end

    def header(pdf)
      pdf.text 'EVENTS BERLIN', size: 10, style: :bold, color: '888888'
      pdf.move_down 6
      pdf.text event.name, size: 24, style: :bold
      pdf.move_down 4
      pdf.text event_date_line, size: 12, color: '444444'
      pdf.move_down 16
      pdf.stroke_horizontal_rule
      pdf.move_down 16
    end

    def details(pdf)
      detail_rows.each { |label, value| detail_row(pdf, label, value) }

      pdf.move_down 24
    end

    def detail_row(pdf, label, value)
      pdf.move_down 3
      row_top = pdf.cursor

      pdf.float { label_cell(pdf, row_top, label) }
      pdf.bounding_box([110, row_top], width: pdf.bounds.width - 110) do
        pdf.text value, size: 11
      end

      pdf.move_down 3
    end

    def label_cell(pdf, row_top, label)
      pdf.bounding_box([0, row_top], width: 110) do
        pdf.text label, style: :bold, color: '666666', size: 11
      end
    end

    def detail_rows
      [
        ['Ticket type', ticket.ticket_type.name],
        ['Location', location_line],
        ['Order', ticket.order&.reference || '—'],
        ['Issued to', ticket.holder&.email || '—']
      ]
    end

    def location_line
      return event.location.to_s if event.venue.nil?

      [event.venue.name, event.venue.address].compact.join(', ')
    end

    def event_date_line
      event.date&.strftime('%A, %-d %B %Y at %H:%M') || '—'
    end

    def qr_section(pdf)
      pdf.text 'Present this code at the door', size: 10, color: '666666'
      pdf.move_down 10
      pdf.render_qr_code(RQRCode::QRCode.new(ticket.code), level: :h, extent: 160, stroke: false)
      pdf.move_down 10
      pdf.text ticket.code, size: 14, style: :bold
      pdf.move_down 4
      pdf.text 'If the scanner fails, this code can be entered by hand.', size: 8, color: '999999'
    end

    def footer(pdf)
      pdf.move_down 30
      pdf.stroke_horizontal_rule
      pdf.move_down 8
      pdf.text 'This ticket admits one person. It is valid only once.', size: 8, color: '999999'
    end
  end
end
