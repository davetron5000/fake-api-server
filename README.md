# Fake API Server

This is a real server that will allow our app to make real HTTP calls, but the server itself doesn't do anything
real.  The server does, however, allow us to simulate various problems that may happen when integrating real third
party code, such as slow responses, interrupted responses, and other issues.

## Forcing Bad Behavior

The following headers, if set, will make the server behave badly:

* `X-Be-Slow` - If set to "true", will sleep a random amount of time. If set to a number, will sleep that many
seconds.
* `X-Throttle` - If set to "true" will return a 429.
* `X-Crash` - If set to "true" will return a 503 or 504.

Slow and Throttle or Slow and Crash can be combined.

## Use Cases

### Charging Credit Card

This will simulate charging a credit card that may be declined.

```
POST /payments/charge
```

Request:

```json
{
  "customer_id": 88,
  "payment_method_id": 99,
  "amount_cents": 6510,
  "metadata": {
    "order_id": 44,
  }
}
```

`metadata` is optional and can be anything.

* If `amount_cents` is `9999`, the charge will be declined.
* If a charge comes in with a previously-used `customer_id` and `amount_cents`, the charge will be declined as
fraud.  This state is remembered in memory so does not persist across restarts.

#### Success Response

HTTP Status: 201

```json
{
  "status": "success",
  "charge_id": "A charge id"
}
```

#### Decline Response

HTTP Status: 200

```json
{
  "status": "declined",
  "explanation": "some explanation"
}
```

### Generate a Fulfillment Request

This simulates requesting the fulfillment of an order

```
PUT /fulfillment/request
```

Request:

```json
{
  "customer_id": 45,
  "address": "123 any st",
  "metadata": {
    "order_id": 44,
  }
}
```

If the address is missing, this request will be rejected, otherwise accepted.

#### Success Response

HTTP Status: 202

```json
{
  "status": "accepted",
  "request_id": "ID of the fulfillment request"
}
```

#### Decline Response

HTTP Status: 422

```json
{
  "status": "rejected",
  "error": "some explanation"
}
```

### Sending an Email

This simulates triggering an email to be sent

```
POST /email/send
```

Request:

```json
{
  "to": "pat@example.com",
  "template_id": "12345",
  "template_data": {
    "name": "Pat",
    "order_id": 44,
  }
}
```

`template_data` can be anything.  `to` and `template_id` are required.
If the address is missing, this request will be rejected, otherwise accepted.

#### Success Response

HTTP Status: 202

```json
{
  "status": "queued",
  "email_id": "ID of the fulfillment request"
}
```

#### Failure Response

HTTP Status: 422

```json
{
  "status": "not-queued",
  "errorMessage": "Some error message"
}
```

### Perform Error-Catching (e.g. like Bugsnag)

This simulates receiving an uncaught error

```
PUT /error-catcher/notification
```

Request:

```json
{
  "exception_class": "StandardError",
  "exception_message": "Something went wrong!"
}
```

Both keys are required

#### Success Response

HTTP Status: 202

```json
{
  "notification_id": "ID of the notification"
}
```

#### Decline Response

HTTP Status: 422

```json
{
  "error": "some explanation"
}
```

### View Caught Errors

These are stored in memory:

```
GET /error-catcher/notifications
```

`GET /` will redirect to this

## Setup and Running Locally

### One Time Setup

1. Clone this repo
1. Install Docker Desktop
1. `dx/setup` then answer whatever questions it asks
1. `dx/start`

### Running & Developing

1. Do the setup above, including `dx/start`
1. Set up the app's dependencies
   1. In a new terminal window `dx/exec bash` - You are logged into the running container.
   1. `bin/setup`
1. Run tests with `bin/test`
1. Run tests and security checks with `bin/ci`
1. Run server locally with `bin/run`

## Integration with Sidekiq Book Stuff

1. Be sure that `Dockerfile` and `Dockerfile.dx` are consistent
1. Edit `bin/version`
1. `bin/docker-build`
1. `bin/push-dockerhub`
1. Edit the sidekiq book's `automation/docker-compose.yml` to use the new version
