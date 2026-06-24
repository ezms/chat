FROM oven/bun:1

RUN apt-get update && apt-get install -y \
    git curl unzip wget build-essential \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

RUN bun add -g @bufbuild/protoc-gen-es
