# frozen_string_literal: true

module Api
  module V1
    class TicketsController < BaseController
      def show
        ticket = find_ticket
        authorize ticket, :validate?

        render json: ticket, serializer: TicketSerializer
      end

      def check_in
        ticket = find_ticket
        authorize ticket, :check_in?

        result = Tickets::CheckInService.new(ticket: ticket, scanned_by: current_user).call

        if result[:success]
          render json: result[:ticket], serializer: TicketSerializer
        else
          render json: check_in_error(result), status: status_for(result[:code])
        end
      end

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

      def check_in_error(result)
        {
          error: result[:error],
          code: result[:code],
          checked_in_at: result[:checked_in_at],
          checked_in_by: result[:checked_in_by]
        }.compact
      end

      def status_for(code)
        code == :already_checked_in ? :conflict : :unprocessable_entity
      end
    end
  end
end
