FROM ruby:3.2

ENV BINDING="0.0.0.0"
ENV PORT=4000
EXPOSE 4000

COPY . fake-api-server
WORKDIR fake-api-server

RUN bin/setup
ENTRYPOINT bin/run
