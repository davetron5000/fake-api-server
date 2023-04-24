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
