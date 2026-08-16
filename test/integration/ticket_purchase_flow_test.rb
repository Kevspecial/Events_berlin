# frozen_string_literal: true

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class TicketPurchaseFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @event = events(:one)
    @event.update!(date: 30.days.from_now, cancel_cutoff_hours: 24)
    @ga = ticket_types(:one)
    @vip = ticket_types(:two)
  end

  def auth_headers(user = @user)
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    { 'Authorization' => "Bearer #{token}" }
  end

  def stub_checkout_session
    stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { id: 'cs_flow', url: 'https://checkout.stripe.com/c/pay/cs_flow' }.to_json
      )
  end

  def stub_refund
    stub_request(:post, 'https://api.stripe.com/v1/refunds')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { id: 're_flow', object: 'refund', status: 'succeeded' }.to_json
      )
  end

  def deliver_webhook(order)
    stripe_event = Stripe::Event.construct_from(
      type: 'checkout.session.completed',
      data: {
        object: {
          id: 'cs_flow', object: 'checkout.session',
          payment_intent: 'pi_flow', metadata: { 'order_id' => order.id.to_s }
        }
      }
    )

    Stripe::Webhook.stub(:construct_event, stripe_event) do
      post '/api/v1/checkout/webhook',
           params: '{}',
           headers: { 'HTTP_STRIPE_SIGNATURE' => 't=1,v1=fake', 'CONTENT_TYPE' => 'application/json' }
    end
  end

  # rubocop:disable Metrics/BlockLength
  test 'buys across two tiers, receives tickets, downloads one, then cancels' do
    stub_checkout_session
    stub_refund

    # 1. Build a cart spanning two tiers
    post "/api/v1/events/#{@event.id}/orders",
         params: { items: [
           { ticket_type_id: @ga.id, quantity: 2 },
           { ticket_type_id: @vip.id, quantity: 1 }
         ] },
         headers: auth_headers, as: :json

    assert_response :created
    order_id = response.parsed_body['id']
    order = Order.find(order_id)
    assert_equal 'pending', order.status
    assert_equal (@ga.price * 2) + @vip.price, order.total_amount

    # 2. Inventory is held while the order is pending
    assert_equal 96, @ga.reload.available_quantity

    # 3. Start checkout
    post "/api/v1/orders/#{order_id}/checkout", headers: auth_headers, as: :json
    assert_response :success
    assert_equal 'https://checkout.stripe.com/c/pay/cs_flow', response.parsed_body['checkout_url']

    # 4. Stripe confirms payment
    perform_enqueued_jobs do
      deliver_webhook(order)
    end
    assert_response :success

    order.reload
    assert_equal 'paid', order.status
    assert_equal 3, order.tickets.count
    assert order.tickets.all?(&:issued?)

    # 5. The buyer got an email with one PDF per ticket
    mail = ActionMailer::Base.deliveries.last
    assert_equal [@user.email], mail.to
    assert_equal 3, (mail.attachments.count { |a| a.content_type.start_with?('application/pdf') })

    # 6. Each ticket downloads as a PDF
    ticket = order.tickets.first
    get "/api/v1/tickets/#{ticket.code}/download", headers: auth_headers
    assert_response :success
    assert response.body.start_with?('%PDF')

    # 7. An organiser checks one in
    @event.update!(date: 1.hour.from_now)
    post "/api/v1/tickets/#{ticket.code}/check_in",
         headers: auth_headers(@event.creator), as: :json
    assert_response :success
    assert ticket.reload.checked_in?

    # 8. Cancelling is refused once a ticket has already been used at the door
    @event.update!(date: 30.days.from_now)
    delete "/api/v1/orders/#{order_id}",
           params: { reason: 'change_of_plans' }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal 'already_attended', response.parsed_body['code']
    order.reload
    assert_equal 'paid', order.status
    assert order.tickets.none?(&:cancelled?)
    assert_equal 96, @ga.reload.available_quantity
  end
  # rubocop:enable Metrics/BlockLength

  test 'a free event issues tickets without touching Stripe' do
    free_event = events(:two)
    free_event.update!(date: 30.days.from_now)
    free_tier = TicketType.create!(event: free_event, name: 'Free entry', price: 0, quantity: 50)

    perform_enqueued_jobs do
      post "/api/v1/events/#{free_event.id}/orders",
           params: { items: [{ ticket_type_id: free_tier.id, quantity: 2 }] },
           headers: auth_headers, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'paid', body['status']

    order = Order.find(body['id'])
    assert_equal 2, order.tickets.count
    assert_not_requested :post, 'https://api.stripe.com/v1/checkout/sessions'

    mail = ActionMailer::Base.deliveries.last
    assert_equal 2, (mail.attachments.count { |a| a.content_type.start_with?('application/pdf') })
  end

  test 'an abandoned order releases its inventory when it expires' do
    post "/api/v1/events/#{@event.id}/orders",
         params: { items: [{ ticket_type_id: @ga.id, quantity: 10 }] },
         headers: auth_headers, as: :json

    assert_response :created
    assert_equal 88, @ga.reload.available_quantity

    Order.find(response.parsed_body['id']).update!(expires_at: 1.minute.ago)
    OrderExpiryJob.perform_now

    assert_equal 98, @ga.reload.available_quantity
  end
end
# rubocop:enable Metrics/ClassLength
