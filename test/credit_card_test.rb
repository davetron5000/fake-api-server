require "fake_api_server"
require "rack/test"
require "json"

class CreditCardTest < Minitest::Test
  include Rack::Test::Methods

  def app = Sinatra::Application

  def test_status
    get "/payments/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
  end

  def test_success
    request = {
      customer_id: 88,
      payment_method_id: 99,
      amount_cents: 65_10,
      metadata: {
        order_id: 44,
      }
    }.to_json
    post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 201,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "success", response["status"]
    refute_nil response["charge_id"]
  end

  def test_fraud_if_immediate_dupe
    request = {
      customer_id: 47,
      payment_method_id: 99,
      amount_cents: 65_10,
      metadata: {
        order_id: 44,
      }
    }.to_json
    post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 201,last_response.status

    post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "declined", response["status"]
    assert_equal "Possible fraud", response["explanation"]
    assert_nil response["charge_id"]

    request2 = {
      customer_id: 46,
      payment_method_id: 99,
      amount_cents: 65_10,
      metadata: {
        order_id: 44,
      }
    }.to_json
    post "/payments/charge", request2, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 201,last_response.status

    post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 201,last_response.status
  end

  def test_not_fraud_if_immediate_dupe_with_idempotency_key
    request = {
      customer_id: 49,
      payment_method_id: 99,
      amount_cents: 65_10,
      metadata: {
        order_id: 44,
        idempotency_key: "123",
      }
    }.to_json
    post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 201,last_response.status

    post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 201,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "success", response["status"]
    refute_nil response["charge_id"]
  end

  if ENV["INCLUDE_SLOW"] == "true"
    def test_not_fraud_if_immediate_dupe_but_delay
      request = {
        customer_id: 45,
        payment_method_id: 99,
        amount_cents: 65_10,
        metadata: {
          order_id: 44,
        }
      }.to_json
      post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
      assert_equal 201,last_response.status
      sleep 5

      post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
      assert_equal 201,last_response.status
    end
  end

  def test_decline
    request = {
      customer_id: 33,
      payment_method_id: 99,
      amount_cents: 99_99, # magic amount
      metadata: {
        order_id: 44,
      }
    }.to_json
    post "/payments/charge", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "declined", response["status"]
    assert_equal "Insufficient funds", response["explanation"]
    assert_nil response["charge_id"]
  end
  def test_decline_retries_with_idempotency_key
    request = {
      customer_id: 33,
      payment_method_id: 99,
      amount_cents: 99_99, # magic amount
      metadata: {
        order_id: 44,
        idempotency_key: "2344",
      }
    }
    post "/payments/charge", request.to_json, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "declined", response["status"]
    assert_equal "Insufficient funds", response["explanation"]
    assert_nil response["charge_id"]

    # Now, try again, but change the amount only to avoid the magic behavior
    request[:amount_cents] = 99_98
    post "/payments/charge", request.to_json, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 201,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "success", response["status"]
    refute_nil response["charge_id"]
  end

  def test_nonsense
    post "/payments/charge", "foo bar blah: ", { "HTTP_ACCEPT" => "application/json" }
    assert_equal 422,last_response.status
  end
end
