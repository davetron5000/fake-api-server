FROM ruby:3.2

# Allows rails server to be accessible outside this docker container
ENV BINDING="0.0.0.0"
ENV PORT=4000
# This says to expose the given port to the outside world.
EXPOSE 4000

COPY . fake-api-server
WORKDIR fake-api-server

RUN bin/setup
ENTRYPOINT bin/run
# vim: ft=Dockerfile
