FROM elixir:1.17

RUN apt-get update && apt-get install -y \
    git curl unzip wget build-essential \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

# protoc-gen-elixir — gera módulos Elixir a partir do .proto
RUN mix escript.install hex protobuf --force
ENV PATH="/root/.mix/escripts:$PATH"

# Bun — backend/ e frontend/
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# protoc-gen-es — gera tipos TypeScript a partir do .proto
RUN bun add -g @bufbuild/protoc-gen-es
