# frozen_string_literal: true

module Api
  module V1
    class OrdersController < BaseController
      include Pagy::Backend

      # The `:attributes` adapter only embeds first-level associations by
      # default (config.default_includes = '*'), so bookings render without
      # their own ticket_type/tickets unless the tree is spelled out here.
      ORDER_INCLUDES = 'event,bookings.ticket_type,bookings.tickets'

      def index
        scope = policy_scope(Order).includes(:event, bookings: %i[ticket_type tickets]).order(created_at: :desc)
        pagy, orders = pagy(scope)

        render json: {
          orders: ActiveModelSerializers::SerializableResource.new(
            orders, each_serializer: OrderSerializer, include: ORDER_INCLUDES
          ),
          meta: { page: pagy.page, pages: pagy.pages, count: pagy.count, items: pagy.vars[:items] }
        }
      end

      def show
        order = policy_scope(Order).includes(bookings: %i[ticket_type tickets]).find(params[:id])
        authorize order
        render json: order, serializer: OrderSerializer, include: ORDER_INCLUDES
      end

      def create
        event = Event.find(params[:event_id])
        authorize Order.new(user: current_user, event: event), :create?

        result = Orders::CreationService.new(user: current_user, event: event, items: order_items).call

        if result[:success]
          render json: result[:order], serializer: OrderSerializer, include: ORDER_INCLUDES, status: :created
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end

      private

      def order_items
        params.require(:items).map { |item| item.permit(:ticket_type_id, :quantity).to_h }
      end
    end
  end
end
