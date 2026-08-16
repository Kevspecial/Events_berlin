# frozen_string_literal: true

module Orders
  # Turns a cart of {ticket_type_id, quantity} pairs into a pending Order with
  # one Booking line item per tier. A zero-total order skips Stripe entirely and
  # is born paid.
  class CreationService
    attr_reader :user, :event, :items

    def initialize(user:, event:, items:)
      @user = user
      @event = event
      @items = Array(items).map { |item| normalise(item) }
    end

    Halt = Class.new(StandardError) do
      attr_reader :payload

      def initialize(payload)
        @payload = payload
        super(payload[:error])
      end
    end

    def call
      error = validate_shape
      return error if error

      ActiveRecord::Base.transaction do
        tiers = lock_tiers
        availability_error = validate_availability(tiers)
        raise Halt, availability_error if availability_error

        build_order(tiers)
      end
    rescue Halt => e
      e.payload
    end

    private

    def normalise(item)
      hash = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
      {
        ticket_type_id: (hash[:ticket_type_id] || hash['ticket_type_id']).to_i,
        quantity: (hash[:quantity] || hash['quantity']).to_i
      }
    end

    def failure(code, message)
      { success: false, error: message, code: code }
    end

    def validate_shape
      validate_cart_shape || validate_event_timing || validate_cart_cap
    end

    def validate_cart_shape
      return failure(:invalid_items, 'Your cart is empty') if items.empty?

      failure(:invalid_items, 'Every ticket quantity must be at least 1') if items.any? { |i| i[:quantity] < 1 }
    end

    def validate_event_timing
      return nil unless event.date.present? && event.date <= Time.current

      failure(:event_past, 'This event has already started')
    end

    def validate_cart_cap
      cap = event.ticket_cap
      total = items.sum { |i| i[:quantity] }
      return nil unless cap && total > cap

      failure(:cap_exceeded, "You can order at most #{cap} tickets for this event")
    end

    # Row-locks each tier so concurrent buyers can't both read stale availability.
    def lock_tiers
      tiers = {}
      event.ticket_types.where(id: items.pluck(:ticket_type_id)).find_each do |tier|
        tier.lock!
        tiers[tier.id] = tier
      end
      tiers
    end

    def validate_availability(tiers)
      items.each do |item|
        tier = tiers[item[:ticket_type_id]]
        return failure(:invalid_items, 'One of the selected ticket types is not available for this event') if tier.nil?

        if tier.available_quantity < item[:quantity]
          return failure(:sold_out, "Only #{tier.available_quantity} #{tier.name} ticket(s) remain")
        end
      end

      nil
    end

    def build_order(tiers)
      total = items.sum { |item| tiers[item[:ticket_type_id]].price * item[:quantity] }
      free = total.zero?

      order = create_order(total, free)
      create_bookings(order, tiers, free)

      { success: true, order: order.reload }
    end

    def create_order(total, free)
      Order.create!(
        user: user,
        event: event,
        status: free ? 'paid' : 'pending',
        payment_status: free ? 'paid' : 'unpaid',
        total_amount: total,
        expires_at: Order.default_expiry,
        paid_at: free ? Time.current : nil
      )
    end

    def create_bookings(order, tiers, free)
      items.each do |item|
        order.bookings.create!(
          user: user,
          event: event,
          ticket_type: tiers[item[:ticket_type_id]],
          quantity: item[:quantity],
          status: free ? 'confirmed' : 'pending'
        )
      end
    end
  end
end
