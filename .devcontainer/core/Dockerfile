FROM elixir:1.17

RUN apt-get update && apt-get install -y \
    git curl unzip wget build-essential \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

RUN mix escript.install hex protobuf --force
ENV PATH="/root/.mix/escripts:$PATH"
