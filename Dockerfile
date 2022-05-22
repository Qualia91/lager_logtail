# Build stage 0
FROM erlang:25-alpine
RUN apk update
RUN apk add git

# Set working directory
RUN mkdir /buildroot
WORKDIR /buildroot

# Copy our Erlang application
COPY . lager_logtail/

# And build the release
WORKDIR lager_logtail
RUN rebar3 release

# Build stage 1
FROM erlang:25-alpine

# # Install the released application
COPY --from=0 /buildroot/lager_logtail/_build/default/rel/lager_logtail /lager_logtail

CMD "/lager_logtail/bin/lager_logtail" "foreground"