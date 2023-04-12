require "sinatra"
require "json"

set :bind, ENV.fetch("BINDING")
set :port, ENV.fetch("PORT")

$notifications = []
$emails = []
$fulfillment_requests = []

before do
  accept = request.env["HTTP_ACCEPT"].to_s.split(/,/).map(&:strip).map(&:downcase)

  accepts_json = accept.include?("application/json")
  accepts_html = accept.include?("text/html")
  accepts_anything = accept.include?("*/*")
  get_request = request.env["REQUEST_METHOD"]

  html_get = get_request && accepts_html
  json_request = accepts_json || accepts_anything

  if !html_get && !json_request
    halt 406
  end

  begin
    @request_payload = if request.env["CONTENT_LENGTH"] == "0" || accepts_html
                         {}
                       else
                         JSON.parse(request.body.read)
                       end
  rescue => ex
    logger.error ex
    halt 422
  end

  if request.env["HTTP_X_BE_SLOW"]
    time = if request.env["HTTP_X_BE_SLOW"] == "true"
             rand(10) + 1
           else
             request.env["HTTP_X_BE_SLOW"].to_i
           end
    logger.info "Sleeping #{time} seconds"
    sleep time
  end

  if request.env["HTTP_X_THROTTLE"] == "true"
    logger.info "Request to throttle"
    halt 429
  end

  if request.env["HTTP_X_CRASH"] == "true"
    logger.info "Request to crash"
    halt [503,504].sample
  end
end

get "/payments/status" do
  200
end

$charges = []
post "/payments/charge" do
  idempotency_key = @request_payload.dig("metadata","idempotency_key")
  previous_request = if idempotency_key.nil?
                       nil
                     else
                       $charges.detect { |request|
                         request.dig("metadata","idempotency_key") == idempotency_key &&
                         request.dig("response","status") == "success"
                       }
                     end
  if !previous_request.nil?
    [ 201, [], [ previous_request["response"].to_json ] ]
  elsif @request_payload["amount_cents"] == 99_99
    response = {
      "status" => "declined",
      "explanation" => "Insufficient funds"
    }
    $charges << @request_payload.merge({ "time" => Time.now, "response" => response })
    [ 200, [], [ response.to_json ] ]
  else
    response = {
      "status" => "success",
      "charge_id" => "ch_#{SecureRandom.uuid}",
    }
    $charges << @request_payload.merge({ "time" => Time.now, "response" => response })
    [ 201, [], [ response.to_json ] ]
  end
end

get "/fulfillment/status" do
  [ 200, [], [ { num_requests: $fulfillment_requests.size }.to_json ] ]
end

put "/fulfillment/request" do
  idempotency_key = @request_payload.dig("metadata","idempotency_key")
  previous_request = if idempotency_key.nil?
                       nil
                     else
                       $fulfillment_requests.detect { |request| request.dig("metadata","idempotency_key") == idempotency_key }
                     end
  if !previous_request.nil?
    [ 202, [], [ previous_request["response"].to_json ] ]
  else
    if @request_payload["address"].to_s.strip == ""
      response = {
        status: "rejected",
        error: "Missing address",
      }
      [ 422, [], [ response.to_json ] ]
    else
      response = {
        status: "accepted",
        request_id: SecureRandom.uuid,
      }
      $fulfillment_requests << @request_payload.merge({ "response" => { "status" => "accepted", "request_id" => response[:request_id] }})
      [ 202, [], [ response.to_json ] ]
    end
  end
end

get "/email/status" do
  200
end

get "/email/emails" do
  matching_emails = $emails.select { |email|
    email["to"] == params["email"] && email["template_id"] == params["template_id"]
  }
  [ 200, [], [ matching_emails.to_json ] ]
end

post "/email/send" do
  if @request_payload["to"].to_s.strip == ""
    response = {
      status: "not-queued",
      errorMessage: "to required",
    }
    [ 422, [], [ response.to_json ] ]
  elsif @request_payload["template_id"].to_s.strip == ""
    response = {
      status: "not-queued",
      errorMessage: "template_id required",
    }
    [ 422, [], [ response.to_json ] ]
  else
    response = {
      status: "queued",
      email_id: SecureRandom.uuid,
    }
    $emails << @request_payload.merge({ "email_id" => response[:email_id] })
    [ 202, [], [ response.to_json ] ]
  end
end

get "/error-catcher/status" do
  200
end

put "/error-catcher/notification" do
  notification = {
    time: Time.now,
    exception: @request_payload["exception_class"],
    message: @request_payload["exception_message"],
  }
  if notification[:exception].to_s.strip == "" ||
      notification[:message].to_s.strip == ""
    response = {
      error: "exception class or message is missing"
    }
    [ 422, [], [ response.to_json ] ]
  else
    response = {
      notification_id: SecureRandom.uuid,
    }
    $notifications << notification
    [ 202, [], [ response.to_json ] ]
  end
end

ERROR_CATCHER_HEAD = %{
  <style>
  * {
    font-family: avenir, helvetica, sans-serif;
    color: #222;
  }

  main { padding: 1rem; }

  h1, h2 {
    margin: 0;
    font-weight: 500;
  }
  h1 {
    text-transform:uppercase;
    letter-spacing: 2
  }
  h2 {
    margin-top: 0.5rem;
  }

  table {
    border-collapse: collapse;
    width: 50%;
  }
  table th, table td {
    border: solid thin #444;
    padding: 0.5rem;
  }
  table td:nth-child(1) {
    white-space: nowrap;
  }
  table td:nth-child(2) {
    font-family: courier, monospace;
  }
  table th {
    text-align: left;
    font-size: 110%;
    font-weight: 500;
    background-color: #dfdfdf;
  }
  p {
    line-height: 1.4;
  }

  </style>
}
get "/" do
  redirect "/error-catcher/notifications"
end
delete "/error-catcher/notifications" do
  $notifications = []
  200
end
get "/error-catcher/notifications" do
  notifications_html = if $notifications.empty?
                         "<tr><td colspan='3'>NONE YET</td></tr>"
                       else
                         $notifications.map { |notification|
    "    <tr>\n" +
    "      <td>"    + notification[:time].to_s + "</td>\n" +
    "      <td>"    + notification[:exception] + "</td>\n" +
    "      <td><p>" + notification[:message]   + "</p></td>\n" +
    "    </tr>\n"
  }.join("\n")
                       end
  response = %{
<html>
<head>#{ ERROR_CATCHER_HEAD }</head>
<body><main>
<h1>Mock Error Catcher</h1>
<h2>Notifications</h2>
<table>
  <thead>
    <tr>
      <th>Time</th>
      <th>Exception</th>
      <th>Message</th>
    </tr>
  </thead>
  <tbody>
#{ notifications_html }
  </tbody>
</table>
</main></body></html>}
  [
    200,
    {
      "Content-Type": "text/html",
    },
    response
  ]
end
