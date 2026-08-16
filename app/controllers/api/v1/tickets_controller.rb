# frozen_string_literal: true

module Api
  module V1
    class TicketsController < BaseController
      def download
        ticket = find_ticket
        authorize ticket, :download?

        if ticket.cancelled?
          return render json: { error: 'This ticket has been cancelled', code: 'cancelled' },
                        status: :unprocessable_entity
        end

        renderer = Tickets::PdfRenderer.new(ticket: ticket)
        send_data renderer.render,
                  filename: renderer.filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      private

      def find_ticket
        Ticket.includes(:booking, :event, :ticket_type, :holder, :order).find_by!(code: params[:code])
      end
    end
  end
end
