# Fake API Server

This is a real server that will allow our app to make real HTTP calls, but the server itself doesn't do anything
real.  The server does, however, allow us to simulate various problems that may happen when integrating real third
party code, such as slow responses, interrupted responses, and other issues.

## Docker Image

The [Sidekiq Book](https://sidekiqrails.com) uses this app in a Docker Image. You can find it [on Docker
Hub](https://hub.docker.com/r/davetron5000/fake-api-server)

## Setup

Generally, you should not have to run this from this repo unless you are doing development on the server itself. With that out of the
way:

1. [Ensure you have Docker installed](https://docs.docker.com/get-docker/)
1. `dx/setup` (only required one time)
1. `dx/build`
1. `dx/start`
1. Then, in another terminal: `dx/exec bash`
1. You are now "logged in" to the Docker container.

### Dev Workflow

After you "log in" to the container, you can edit code on your computer and it'll be available in the container. The container has Ruby
installed, as well as whatever else is needed to run and test the app.

* `bin/test` will run the tests
* `bin/ci` will run tests and then run `bundle audit`
* `bin/run` will run the app. *Note*: there is no auto-reload, so if you make changes, you have to restart.  The app will be available
at `http://localhost:8888`.  There are minimal UIs for each fake service.
* `bin/mk` **is to be run on your computer** and it will hit the API to do stuff. `bin/mk -h` will give better help

## General Docs

This app contains four fake services: payments, email, order fulfillment, and an error-catcher (like Bugsnag).  Each stores requests
in memory and shows that in a basic UI when you run the app.

The purpose of these existing at all is to have a real networked service the sample app can connect to *and* provide a way to simulate
bad behavior of the services. This can be used to simulate failure modes you will encounter.

To simulate bad behavior, use these headers when making requests:

* `X-Be-Slow` - If set to "true", will sleep a random amount of time. If set to a number, will sleep that many
seconds.
* `X-Throttle` - If set to "true" will return a 429.
* `X-Crash` - If set to "true" will return a 503 or 504.

Slow can be combined with either Crash or Throttle.

## What each file here is

In this directory:

* `.gitignore` - File of files to ignore in Git
* `Dockerfile.dx` - The `Dockerfile` used to build an image you can use to run a container to do the development for the app.
* `Dockerfile` - The `Dockerfile` used to build an image pushed to DockerHub. This is the image used by the book.
* `Gemfile` and `Gemfile.lock` - manages Ruby gems needed for the app.
* `README.md` - This file
* `Rakefile` - holds the test task because I could not figure out a better way to run it without Rake.
* `app/` - The app itself, currently just one big file. Take that, Single Responsibility Principle!
* `bin/` - Directory for scripts relevant to running, testing, or developing the app itself.
* `docker-compose.dx.yml` - A Docker Compose file that runs the app.
* `dx/` - Directory for all the shell scripts and files needed to run the dev environment.
* `test/` - Tests for the app.


## Pushing to DockerHub

1. Be sure that `Dockerfile` and `Dockerfile.dx` are consistent
1. Make sure all tests are passing via `bin/ci` and there are no warnings or other nonsense
1. Edit `bin/docker-hub/vars` to bump the version
1. `bin/docker-hub/build`
1. `bin/docker-hub/push`
1. Edit the sidekiq book's `automation/dev-environment/docker-compose.yml` to use the new version
1. Tag the repo as the same version in step 3 and push that tag

