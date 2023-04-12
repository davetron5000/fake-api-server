require "fake_api_server"
require "rack/test"
require "json"

class EmailTest < Minitest::Test
  include Rack::Test::Methods

  def app = Sinatra::Application

  def test_status
    get "/email/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
  end

  def test_crash_still_sends_email
    request = {
      to: "bobbi@example.com",
      template_id: "2345",
      template_data: {
        name: "Chris",
        order_id: 42,
      }
    }.to_json
    post "/email/send", request, { "HTTP_ACCEPT" => "application/json", "HTTP_X_CRASH" => "true" }
    assert_equal 503,last_response.status

    get "/email/emails", { email: "bobbi@example.com", template_id: "2345" }, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal 1, response.size
    email = response[0]
    assert_equal 42, email["template_data"]["order_id"]
    refute_nil email["email_id"]
  end

  def test_success
    request = {
      to: "pat@example.com",
      template_id: "12345",
      template_data: {
        name: "Pat",
        order_id: 44,
      }
    }.to_json
    post "/email/send", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "queued", response["status"]
    refute_nil response["email_id"]
  end

  def test_ui
    request1 = {
      to: "pat@example.com",
      template_id: "12345",
      template_data: {
        name: "Pat",
        order_id: 44,
      }
    }.to_json
    post "/email/send", request1, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    response1 = JSON.parse(last_response.body)
    refute_nil response1["email_id"]

    request2 = {
      to: "pat@example.com",
      template_id: "12345",
      template_data: {
        name: "Pat",
        order_id: 44,
      }
    }.to_json
    post "/email/send", request2, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    response2 = JSON.parse(last_response.body)
    refute_nil response2["email_id"]

    get "/email/ui", nil, { "HTTP_ACCEPT" => "text/html" }
    body = last_response.body.to_s
    assert_equal 200,last_response.status
    assert_match /#{response1["email_id"]}/, body
    assert_match /#{response2["email_id"]}/, body
  end

  def test_missing_template_id
    request = {
      to: "pat@example.com",
      template_data: {
        name: "Pat",
        order_id: 44,
      }
    }.to_json
    post "/email/send", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 422,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "not-queued", response["status"]
    assert_equal "template_id required", response["errorMessage"]
    assert_nil response["email_id"]
  end

  def test_missing_to
    request = {
      template_id: "1234",
      template_data: {
        name: "Pat",
        order_id: 44,
      }
    }.to_json
    post "/email/send", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 422,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal "not-queued", response["status"]
    assert_equal "to required", response["errorMessage"]
    assert_nil response["email_id"]
  end

  def test_search_emails_none
    get "/email/emails", { email: "cameron@example.com", template_id: "42" }, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal [], response
  end
  def test_search_emails_some
    request = {
      to: "quinn@example.com",
      template_id: "12345",
      template_data: {
        name: "Quinn",
        order_id: 44,
      }
    }.to_json
    post "/email/send", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    request = {
      to: "quinn@example.com",
      template_id: "4567",
      template_data: {
        name: "Quinn",
        order_id: 44,
      }
    }.to_json
    post "/email/send", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    request = {
      to: "chris@example.com",
      template_id: "12345",
      template_data: {
        name: "Chris",
        order_id: 43,
      }
    }.to_json
    post "/email/send", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status

    get "/email/emails", { email: "quinn@example.com", template_id: "12345" }, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
    response = JSON.parse(last_response.body)
    assert_equal 1, response.size
    email = response[0]
    assert_equal 44, email["template_data"]["order_id"]
    refute_nil email["email_id"]
  end

end
