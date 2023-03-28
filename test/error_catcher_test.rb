require "fake_api_server"
require "rack/test"
require "json"

class ErrorCatcherTest < Minitest::Test
  include Rack::Test::Methods

  def app = Sinatra::Application

  def test_status
    get "/error-catcher/status", nil, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 200,last_response.status
  end

  def test_send_bug
    request = {
      exception_class: "StandardError",
      exception_message: "something broke",
      backtrace: [
        "foo:12",
        "bar:13"
      ],
      metadata: {
        some_data: true
      }
    }.to_json
    put "/error-catcher/notification", request, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status
    response = JSON.parse(last_response.body)
    refute_nil response["notification_id"]
  end

  def test_list_notifications
    request1 = {
      exception_class: "StandardError",
      exception_message: "something broke",
      backtrace: [
        "foo:12",
        "bar:13"
      ],
      metadata: {
        some_data: true
      }
    }.to_json
    put "/error-catcher/notification", request1, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status

    request2 = {
      exception_class: "NameError",
      exception_message: "something broke",
      backtrace: [
        "foo:12",
        "bar:13"
      ],
      metadata: {
        some_data: true
      }
    }.to_json
    put "/error-catcher/notification", request2, { "HTTP_ACCEPT" => "application/json" }
    assert_equal 202,last_response.status

    get "/error-catcher/notifications", nil, { "HTTP_ACCEPT" => "text/html" }
    body = last_response.body.to_s
    assert_equal 200,last_response.status
    assert_match /NameError/,body
    assert_match /StandardError/,body

  end

end
