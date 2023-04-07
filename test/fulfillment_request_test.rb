require "fake_api_server"
require "rack/test"
require "json"

class FulfillmentRequestTest < Minitest::Test
  include Rack::Test::Methods

  def app = Sinatra::Application

  def test_status
    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    refute_nil response["num_requests"]
  end

  def test_success
    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    num_requests = response["num_requests"]

    request = {
      customer_id: 45,
      address: "123 any st",
      metadata: {
        order_id: 44,
      }
    }.to_json
    put "/fulfillment/request", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "accepted", response["status"]
    refute_nil response["request_id"]

    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal num_requests + 1, response["num_requests"]
  end

  def test_idempotency_key
    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    num_requests = response["num_requests"]

    request = {
      customer_id: 45,
      address: "123 any st",
      metadata: {
        idempotency_key: 44,
      }
    }.to_json
    put "/fulfillment/request", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "accepted", response["status"]
    refute_nil response["request_id"]

    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal num_requests+1, response["num_requests"]

    put "/fulfillment/request", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "accepted", response["status"]
    refute_nil response["request_id"]

    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal num_requests+1, response["num_requests"]
  end

  def test_decline
    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    num_requests = response["num_requests"]

    request = {
      customer_id: 45,
      address: nil,
      metadata: {
        order_id: 44,
      }
    }.to_json
    put "/fulfillment/request", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 422,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "rejected", response["status"]
    assert_equal "Missing address", response["error"]
    assert_nil response["request_id"]

    get "/fulfillment/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal num_requests, response["num_requests"]
  end
end
