FROM elixir:1.17-alpine AS builder

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY core/mix.exs core/mix.lock ./
RUN MIX_ENV=prod mix deps.get --only prod
RUN MIX_ENV=prod mix deps.compile

COPY core/ .
RUN MIX_ENV=prod mix compile
RUN MIX_ENV=prod mix release

# ---------------------------------------------------------------

FROM alpine:3.20 AS runner

RUN apk add --no-cache bash libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/core ./

EXPOSE 4000 50051

ENV MIX_ENV=prod

ENTRYPOINT ["bin/core"]
CMD ["start"]
