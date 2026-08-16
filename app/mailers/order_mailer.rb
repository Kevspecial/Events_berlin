# frozen_string_literal: true

class OrderMailer < ApplicationMailer
  def confirmation(order)
    @order = order
    @event = order.event
    @tickets = order.tickets.includes(:ticket_type).to_a

    return message.perform_deliveries = false if @tickets.empty?

    attach_tickets

    mail(
      to: order.user.email,
      subject: "Your tickets for #{@event.name}"
    )
  end

  private

  def attach_tickets
    @tickets.each { |ticket| attach_ticket(ticket) }
  end

  def attach_ticket(ticket)
    renderer = Tickets::PdfRenderer.new(ticket: ticket)
    attachments[renderer.filename] = { mime_type: 'application/pdf', content: renderer.render }
  rescue StandardError => e
    # A single unrenderable ticket must not sink the whole confirmation.
    # The buyer can still download it from their order page.
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
