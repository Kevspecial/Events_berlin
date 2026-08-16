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

        items = order_items
        return render_invalid_items if items.nil?

        render_creation_result(Orders::CreationService.new(user: current_user, event: event, items: items).call)
      end

      def checkout
        order = policy_scope(Order).find(params[:id])
        authorize order, :show?

        result = Orders::CheckoutService.new(order: order).call

        if result[:success]
          render json: { checkout_url: result[:checkout_url], session_id: result[:session_id] }
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end

      def destroy
        order = policy_scope(Order).find(params[:id])
        authorize order, :cancel?

        result = Orders::CancellationService.new(order: order, reason: params[:reason]).call

        if result[:success]
          render json: result[:order], serializer: OrderSerializer, include: ORDER_INCLUDES
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end

      private

      def render_creation_result(result)
        if result[:success]
          render json: result[:order], serializer: OrderSerializer,
                 include: ORDER_INCLUDES, status: :created
        else
          render json: { error: result[:error], code: result[:code] }, status: :unprocessable_entity
        end
      end

      # Returns nil when the payload is not a well-formed items array, so the
      # caller can answer with the project's {error:, code:} envelope rather
      # than letting ParameterMissing escape as an HTML 400.
      def order_items
        raw = params[:items]
        return nil unless raw.is_a?(Array)

        raw.map do |item|
          next nil unless item.respond_to?(:permit)

          item.permit(:ticket_type_id, :quantity).to_h
        end.compact
      end

      def render_invalid_items
        render json: {
          error: 'Provide items as an array of ticket_type_id and quantity pairs',
          code: 'invalid_items'
        }, status: :unprocessable_entity
      end
    end
  end
end
