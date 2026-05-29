# Chat Service

A standalone, generic and integrable real-time messaging service. Designed to be the chat backbone for any application — from a simple bot interface to a full Slack-like workspace.

> Architecture document: [`docs/architecture.pdf`](docs/architecture.pdf)

---

## Table of Contents

- [Overview](#overview)
- [Distribution Models](#distribution-models)
- [Architecture](#architecture)
- [Stack](#stack)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Docker Compose Profiles](#docker-compose-profiles)
- [Integration Contracts](#integration-contracts)
  - [Authentication](#authentication)
  - [Channel Security](#channel-security)
  - [Object Storage](#object-storage)
  - [Message Broker](#message-broker)
  - [RabbitMQ Events](#rabbitmq-events)
  - [gRPC Admin API](#grpc-admin-api)
- [Development](#development)
- [Testing](#testing)
- [CI/CD](#cicd)

---

## Overview

Chat Service is a real-time messaging service built on Elixir/BEAM. It is atomic — runs standalone without depending on any other system — and integrable — exposes stable contracts via gRPC and RabbitMQ events that any project can consume.

The service manages: **rooms, real-time messaging, delivery guarantees, and presence tracking.**

The service does not manage: identity, user profiles, contact lists, or social graphs. These are the integrator's responsibility.

---

## Distribution Models

The service supports three distribution models:

**Model A — Standalone**
Deploy the full stack and access via browser. Includes the demo frontend and backend. Suitable for self-hosting and portfolio demonstration.

```bash
docker compose --profile local-db --profile local-cache --profile local-queue --profile demo up
```

**Model B — Core only (SDK)**
Deploy only `core`. The integrating system connects via WebSocket using the Protobuf protocol, implements the `Chat.Auth` behaviour, and subscribes to RabbitMQ events.

Pull the published image — no need to clone the repository:

```bash
docker pull ghcr.io/your-username/chat-core:latest
```

Or add it to your existing `docker-compose.yml`:

```yaml
services:
  chat:
    image: ghcr.io/your-username/chat-core:latest
    ports:
      - "4000:4000"
      - "50051:50051"
    environment:
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      RABBITMQ_URL: ${RABBITMQ_URL}
      SCYLLADB_URL: ${SCYLLADB_URL}
      REDIS_URL: ${REDIS_URL}
```

For local development with all services:

```bash
docker compose --profile local-db --profile local-cache --profile local-queue up
```

**Model C — Widget**
Install the published package and embed in any web application:

```bash
bun add @chat/widget
# or
npm install @chat/widget
```

```html
<!-- or via CDN / script tag -->
<script type="module" src="https://unpkg.com/@chat/widget"></script>
<chat-widget server="wss://your-chat-host/socket" token="..." room="..."></chat-widget>
```

The `widget/` directory contains the default implementation. Integrators are free to build their own widget on top of the core JS client.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CHAT SERVICE                            │
│                                                                 │
│  WebSocket (Phoenix Channels)                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Connection Pool (Erlang processes, 1 process/connection)│   │
│  │  · Heartbeat / automatic reconnect                       │   │
│  │  · Sequence numbers per channel                          │   │
│  │  · Explicit ack (at-least-once delivery)                 │   │
│  └──────────────┬───────────────────────────────────────────┘   │
│                 │                                               │
│     ┌───────────┼───────────┐                                   │
│     ▼           ▼           ▼                                   │
│  [Room Mgr]  [Presence]  [Fan-out]                              │
│  ScyllaDB    CRDT distrib  RabbitMQ exchange                    │
│     │                         │                                 │
│     ▼                         ▼                                 │
│  [ScyllaDB]           [Offline Queue]                           │
│  message history      delivered on reconnect                    │
└─────────────────────────────────────────────────────────────────┘
         │                              │
         │ gRPC                         │ RabbitMQ events
         ▼                              ▼
  any integrating system         any integrating system
```

### Core Components

| Component | Responsibility |
|---|---|
| **Gateway WS** | Accepts connections, delegates token validation to `Chat.Auth`, distributes to channels. One Erlang process per connection. |
| **Room Manager** | Manages channels (workspace channels, DMs, broadcast). Persists metadata and membership in ScyllaDB. |
| **Presence** | Phoenix Presence CRDT — distributed without central coordination. Tracks online/offline per channel. |
| **Fan-out Engine** | Publishes messages to RabbitMQ exchange. Any integrating system subscribes to its own queue. |
| **Offline Queue** | Holds messages for disconnected users. Delivered in order on reconnect via sequence number. |
| **Message Store** | ScyllaDB partitioned by `channel_id`, clustered by `sequence_number`. Paginated history via cursor. |

---

## Stack

| Decision | Choice | Rationale |
|---|---|---|
| Runtime | Elixir / Erlang OTP | The BEAM is the architecture — distributed presence (CRDT), connection isolation, and fault tolerance are structural properties of the runtime. |
| Real-time | Phoenix Channels | Native multiplexing, the model that inspired the Discord Gateway. |
| Serialization | Protobuf | Versioned schema, binary, explicit contracts between client and server. `proto/messages.proto` is the source of truth for both Elixir and TypeScript. |
| Presence | Phoenix Presence | Distributed CRDT — no central coordinator, eventual consistency. |
| Message history | ScyllaDB | Wide-column, native time-series. Partition key: `channel_id`, clustering key: `sequence_number`. High write throughput, paginated cursor reads. Modern C++ Cassandra. |
| Presence & cache | Redis | Natural TTL for ephemeral events (typing, last_seen). Pub/sub for cross-node presence notifications. |
| Fan-out | RabbitMQ | Topic exchange for generic routing by workspace/channel. Integrators subscribe to their own queues. |
| Search | Meilisearch | Open source search engine, self-hostable, written in Rust. Async indexing via RabbitMQ consumer. ScyllaDB is the primary store — Meilisearch is the index only. *(M9+)* |
| Object storage | MinIO | S3-compatible, self-hostable. Stores files and media. Access via presigned URLs. Replaceable by S3, R2, Oracle Storage via `Chat.Contracts.Storage` behaviour. |
| Backend (demo) | Bun + Elysia | REST API serving the standalone frontend. Exists for demonstration and self-hosting — not part of the service core. |
| Frontend (demo) | Svelte | Standalone UI for demonstration and portfolio. Demonstrates the widget in use. |
| Widget | Svelte → Web Component | Default `<chat-widget>` implementation. Represents Model C. Integrators may build their own widget on top of the core JS client. |

---

## Repository Structure

```
chat/
├── core/                       # Elixir — the service
│   ├── lib/chat/
│   │   ├── core.ex             # OTP Application + root supervisor
│   │   ├── endpoint.ex         # Phoenix Endpoint (WebSocket entry point)
│   │   ├── domain/             # business logic (Phoenix Contexts)
│   │   │   ├── user/
│   │   │   │   └── socket.ex   # UserSocket — handshake, calls Auth.verify/1
│   │   │   ├── messaging/      # send/receive, sequence numbers, history
│   │   │   └── presence/       # Phoenix.Presence CRDT
│   │   └── infra/              # external adapters
│   │       ├── auth/           # Auth.Default — JWT via Joken
│   │       ├── channel_security/ # Passthrough + AESGCM
│   │       ├── database/       # ScyllaDB (Xandra)
│   │       ├── grpc/           # gRPC Admin handlers
│   │       ├── messaging/      # MessageStore, HistoryStore, AckStore
│   │       ├── queue/          # RabbitMQ connection + publisher
│   │       ├── redis/          # Sequence counter
│   │       └── storage/        # Minio — Chat.Contracts.Storage default
│   ├── config/
│   └── mix.exs
│
│
├── backend/                    # Bun + Elysia — REST API (demo)
├── frontend/                   # Svelte — standalone UI (demo)
├── widget/                     # Svelte → Web Component (distributable)
│
├── proto/
│   └── messages.proto          # source of truth: generates Elixir + TypeScript types
│
├── docs/                       # architecture document (PDF + HTML)
├── .devcontainer/              # development environment
├── docker-compose.yml
└── README.md
```

`core/` follows [Phoenix Contexts](https://hexdocs.pm/phoenix/contexts.html): `domain/` holds business logic, `infra/` holds external adapters (database, cache, queue).

---

## Getting Started

### Prerequisites

- Docker and Docker Compose v2.20+
- A `SECRET_KEY_BASE` value (generate with `mix phx.gen.secret` or any 64+ char random string)

### Quickstart — standalone

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Set the required secret
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env

# 3. Start everything
docker compose \
  --profile local-db \
  --profile local-cache \
  --profile local-queue \
  --profile demo \
  up
```

| Service | URL |
|---|---|
| Core (WebSocket) | `ws://localhost:4000/socket` |
| Core (gRPC) | `localhost:50051` |
| Frontend | `http://localhost:5173` |
| Backend API | `http://localhost:3000` |
| RabbitMQ Management | `http://localhost:15672` |

### Core only (integration)

```bash
docker compose \
  --profile local-db \
  --profile local-cache \
  --profile local-queue \
  up
```

### With external services

Set the relevant env vars and omit the corresponding `local-*` profiles:

```bash
SCYLLADB_URL=your-scylla-host:9042 \
REDIS_URL=redis://your-redis-host:6379 \
RABBITMQ_URL=amqp://user:pass@your-rabbit-host:5672 \
docker compose up
```

---

## Configuration

All configuration is via environment variables. Copy `.env.example` to `.env` before running.

### Core (`core/`)

| Variable | Required | Default | Description |
|---|---|---|---|
| `SECRET_KEY_BASE` | Yes | — | Phoenix secret key. Generate with `mix phx.gen.secret`. |
| `SCYLLADB_URL` | No | `scylladb:9042` | ScyllaDB connection. Omit `local-db` profile if set externally. |
| `REDIS_URL` | No | `redis://redis:6379` | Redis connection. Omit `local-cache` profile if set externally. |
| `RABBITMQ_URL` | No | `amqp://chat:chat@rabbitmq:5672` | RabbitMQ connection. Omit `local-queue` profile if set externally. |
| `MINIO_HOST` | No | `minio` | MinIO/S3 host. |
| `MINIO_PORT` | No | `9000` | MinIO/S3 port. |
| `MINIO_ACCESS_KEY` | No | `chatadmin` | MinIO/S3 access key. |
| `MINIO_SECRET_KEY` | No | `changeme` | MinIO/S3 secret key. Change in production. |
| `MINIO_BUCKET` | No | `chat` | Bucket name for file storage. |
| `MEILISEARCH_URL` | No | _(empty)_ | Enables search feature when set. Requires `search` profile or external instance. |
| `MEILISEARCH_KEY` | No | _(empty)_ | Meilisearch master key. |

### Demo services

| Variable | Default | Description |
|---|---|---|
| `CORE_URL` | `http://core:4000` | Backend → Core HTTP URL. |
| `PUBLIC_CORE_WS_URL` | `ws://localhost:4000/socket` | Frontend → Core WebSocket URL. |
| `PUBLIC_BACKEND_URL` | `http://localhost:3000` | Frontend → Backend API URL. |

### Infrastructure (local profiles)

| Variable | Default | Description |
|---|---|---|
| `RABBITMQ_USER` | `chat` | Local RabbitMQ user. |
| `RABBITMQ_PASS` | `chat` | Local RabbitMQ password. |
| `MEILI_MASTER_KEY` | `changeme` | Local Meilisearch master key. Change in production. |
| `MINIO_ROOT_USER` | `chatadmin` | Local MinIO root user. |
| `MINIO_ROOT_PASSWORD` | `changeme` | Local MinIO root password. Change in production. |

---

## Docker Compose Profiles

Profiles are named by feature, not by technology.

| Profile | Starts | When to use |
|---|---|---|
| `local-db` | ScyllaDB | No external ScyllaDB configured |
| `local-cache` | Redis | No external Redis configured |
| `local-queue` | RabbitMQ | No external broker configured |
| `search` | Meilisearch | Search feature enabled *(M9+)* |
| `storage` | MinIO | Media feature enabled |
| `demo` | backend + frontend | Standalone deployment / portfolio |

`core` always starts regardless of profiles.

---

## Integration Contracts

### Authentication

The service delegates token validation to the integrator via the `Chat.Auth` behaviour.

```elixir
defmodule Chat.Contracts.Auth do
  @callback verify(token :: String.t()) ::
    {:ok, %{user_id: String.t(), room_ids: [String.t()]}} | {:error, term()}
end
```

The default implementation validates JWT tokens signed with `SECRET_KEY_BASE`. The token must carry:
- `sub` — the user identifier
- `room_ids` — list of room identifiers the user is allowed to join

The service enforces `room_ids` at join time — a connection attempt to a room not listed in the token is rejected with `unauthorized`. Issuing tokens with the correct `room_ids` is the integrator's responsibility.

To use a different auth mechanism, implement the behaviour and configure it:

```elixir
# config/config.exs
config :core, auth: MyApp.CustomAuth
```

User profiles, display names, and avatars are the integrator's responsibility — the service only receives `user_id` and `room_ids` from `verify/1`.

### Channel Security

By default all payload encryption is handled at the transport layer (TLS). For deployments that need end-to-end encryption at the application layer, the service exposes a pluggable `Chat.Contracts.ChannelSecurity` behaviour.

```elixir
defmodule Chat.Contracts.ChannelSecurity do
  @callback encode(payload :: binary(), assigns :: map()) :: binary()
  @callback decode(payload :: binary(), assigns :: map()) :: {:ok, binary()} | {:error, term()}
  @callback derive_session_key(client_pub_key :: binary()) ::
              {server_pub_key :: binary(), session_key :: binary()}
end
```

**Built-in implementations:**

| Module | Description |
|---|---|
| `Chat.Infra.ChannelSecurity.Passthrough` | Default — no-op, relies on TLS |
| `Chat.Infra.ChannelSecurity.AESGCM` | AES-256-GCM payload encryption with ECDH (X25519) key exchange |

**ECDH handshake (AESGCM):**

1. Client generates an X25519 key pair, sends `client_pub_key` (Base64) alongside `token` in the WebSocket connect params.
2. Server runs ECDH, derives a 32-byte session key (SHA-256 of the shared secret), and returns `server_pub_key` (Base64) in the `join` reply.
3. All subsequent `Envelope` frames are encrypted — nonce (12 bytes) + auth tag (16 bytes) prepended to the ciphertext.

To enable:

```elixir
# config/config.exs
config :core, :channel_security, Chat.Infra.ChannelSecurity.AESGCM
```

To use a custom implementation:

```elixir
config :core, :channel_security, MyApp.CustomChannelSecurity
```

### Object Storage

The service delegates presigned URL generation to the `Chat.Contracts.Storage` behaviour.

```elixir
defmodule Chat.Contracts.Storage do
  @callback presign_upload(file_key :: String.t(), opts :: keyword()) ::
              {:ok, %{upload_url: String.t(), file_key: String.t()}} | {:error, term()}
  @callback presign_download(file_key :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}
end
```

The default implementation uses MinIO (S3-compatible). Files are never proxied through the service — clients upload/download directly from object storage via presigned URLs.

**HTTP endpoints (Bearer token required):**

| Method | Path | Description |
|---|---|---|
| `POST` | `/upload/presign` | Returns `{ upload_url, file_key }` for a direct PUT to MinIO |
| `GET` | `/files/presign?file_key=<key>` | Returns a presigned download URL |

After uploading, the client sends a `SendFile` WebSocket message to persist the file reference and broadcast `FileDelivered` to all room members.

To use S3, R2, Oracle Storage or any other provider, implement the behaviour and configure it:

```elixir
config :core, :storage_module, MyApp.S3Storage
```

### Storage Adapters

The service delegates all persistence to pluggable store contracts. Each store has a default implementation included in the image — replace any of them by implementing the corresponding behaviour and setting it in config.

**Message store (ScyllaDB by default)**

```elixir
defmodule Chat.Contracts.MessageStore do
  @callback insert(room_id :: String.t(), sender_id :: String.t(), content :: binary()) ::
              {:ok, sequence_number :: integer()} | {:error, term()}

  @callback insert_file(room_id :: String.t(), sender_id :: String.t(), file_key :: String.t(),
              filename :: String.t(), content_type :: String.t(), size :: integer()) ::
              {:ok, sequence_number :: integer()} | {:error, term()}
end
```

**History store (ScyllaDB by default)**

```elixir
defmodule Chat.Contracts.HistoryStore do
  @callback get(room_id :: String.t(), after_sequence :: integer(), limit :: integer()) ::
              {:ok, list(map())} | {:error, term()}
end
```

**Reaction store (ScyllaDB by default)**

```elixir
defmodule Chat.Contracts.ReactionStore do
  @callback upsert(room_id :: String.t(), sequence_number :: integer(),
              user_id :: String.t(), emoji :: String.t()) :: :ok | {:error, term()}

  @callback delete(room_id :: String.t(), sequence_number :: integer(),
              user_id :: String.t()) :: :ok | {:error, term()}
end
```

**Thread store (ScyllaDB by default)**

```elixir
defmodule Chat.Contracts.ThreadStore do
  @callback insert_reply(room_id :: String.t(), parent_sequence_number :: integer(),
              sender_id :: String.t(), content :: binary()) ::
              {:ok, sequence_number :: integer()} | {:error, term()}

  @callback count_replies(room_id :: String.t(), parent_sequence_number :: integer()) ::
              {:ok, integer()} | {:error, term()}
end
```

**Ack store (Redis by default)**

```elixir
defmodule Chat.Contracts.AckStore do
  @callback confirm(user_id :: String.t(), room_id :: String.t(), sequence_number :: integer()) ::
              :ok | {:error, term()}

  @callback last_ack(user_id :: String.t(), room_id :: String.t()) ::
              {:ok, integer()} | {:error, term()}
end
```

**Read store (Redis by default)**

```elixir
defmodule Chat.Contracts.ReadStore do
  @callback mark_read(user_id :: String.t(), room_id :: String.t(), sequence_number :: integer()) ::
              :ok | {:error, term()}

  @callback last_read(user_id :: String.t(), room_id :: String.t()) ::
              {:ok, integer()} | {:error, term()}
end
```

**Default implementations**

| Contract | Default | Backend |
|---|---|---|
| `Chat.Contracts.MessageStore` | `Chat.Infra.Scylla.MessageStore` | ScyllaDB |
| `Chat.Contracts.HistoryStore` | `Chat.Infra.Scylla.HistoryStore` | ScyllaDB |
| `Chat.Contracts.ReactionStore` | `Chat.Infra.Scylla.ReactionStore` | ScyllaDB |
| `Chat.Contracts.ThreadStore` | `Chat.Infra.Scylla.ThreadStore` | ScyllaDB |
| `Chat.Contracts.AckStore` | `Chat.Infra.Redis.AckStore` | Redis |
| `Chat.Contracts.ReadStore` | `Chat.Infra.Redis.ReadStore` | Redis |

**Using a custom backend**

Implement the relevant behaviours in your own package, then configure them:

```elixir
# config/config.exs (or runtime.exs)
config :core, message_store: MyApp.DynamoMessageStore
config :core, history_store: MyApp.DynamoHistoryStore
config :core, reaction_store: MyApp.DynamoReactionStore
config :core, thread_store: MyApp.DynamoThreadStore
config :core, ack_store: MyApp.PostgresAckStore
config :core, read_store: MyApp.PostgresReadStore
```

You may replace any subset — for example, keep the ScyllaDB stores and only swap the Redis stores for a Postgres implementation. Each contract is independent.

> **Note on sequence numbers:** `MessageStore` and `ThreadStore` implementations are responsible for generating monotonically increasing `sequence_number` values internally. The default ScyllaDB implementation uses Redis `INCR` for this. Alternative implementations should use the atomic counter mechanism native to their backend (e.g. PostgreSQL sequences, DynamoDB atomic counters).

---

### Message Broker

If your system already runs a RabbitMQ instance, point the service to it via `RABBITMQ_URL`. No code changes are required — the service connects to whichever broker is configured.

```bash
RABBITMQ_URL=amqp://user:pass@your-broker:5672
```

Omit the `local-queue` profile when using an external broker.

### RabbitMQ Events

The service publishes domain events to a RabbitMQ topic exchange. Any integrating system subscribes to its own queue — the service has no knowledge of consumers.

**Published by the service:**

| Exchange | Routing Key | Payload |
|---|---|---|
| `chat.events` | `message.sent` | `room_id, sender_id, sequence_number, content, inserted_at` |
| `chat.events` | `presence.changed` | `room_id, user_id, status (online/offline)` |
| `chat.events` | `push.notify` | `room_id, sender_id, sequence_number, inserted_at` — fired on every new message, reply, or file; the integrator decides who to notify and via which channel (FCM, APNs, Web Push) |

Routing keys follow the pattern `<object>.<verb>`, allowing consumers to bind selectively (e.g. `message.*` for all message events, `#` for everything).

### gRPC Admin API

Exposed on port `50051`. The service does not manage room lifecycle — room creation and membership are the integrator's responsibility (enforced via JWT `room_ids`). The Admin API covers operational access: reading history and injecting system messages.

```protobuf
service ChatAdmin {
  rpc GetHistory    (HistoryRequest)       returns (stream HistoryMessage);
  rpc SendSystemMsg (SystemMessageRequest) returns (SystemAck);
}
```

### Message Protocol (Protobuf)

Messages are transmitted as **Protobuf over WebSocket**. The `proto/messages.proto` file is the source of truth — it generates types for both Elixir (via `protoc-gen-elixir`) and TypeScript (via `protoc-gen-es`).

All frames are wrapped in an `Envelope` with a `oneof payload`:

```protobuf
message Envelope {
  oneof payload {
    Ping             ping             = 1;
    Pong             pong             = 2;
    SendMessage      send_message     = 3;
    MessageDelivered message_delivered = 4;
    Ack              ack              = 5;
    TypingEvent      typing_event     = 6;
    PresenceState    presence_state   = 7;
    SendFile         send_file        = 8;
    FileDelivered    file_delivered   = 9;
    AddReaction      add_reaction     = 10;
    RemoveReaction   remove_reaction  = 11;
    ReactionUpdate   reaction_update  = 12;
    ReadReceipt      read_receipt     = 13;
    ReadUpdate       read_update      = 14;
    SendReply        send_reply       = 15;
    ReplyDelivered   reply_delivered  = 16;
    ThreadUpdate     thread_update    = 17;
  }
}
```

**Client → Server:**

| Message | Description |
|---|---|
| `Ping` | Heartbeat — server replies with `Pong` |
| `SendMessage` | Send a text message to a room (`room_id`, `content`) |
| `SendFile` | Send a file reference to a room (`room_id`, `file_key`, `filename`, `content_type`, `size`) |
| `Ack` | Confirm delivery of a message (`room_id`, `sequence_number`) |
| `TypingEvent` | Typing indicator (`room_id`, `is_typing`) — server injects `user_id` before broadcasting |
| `AddReaction` | Add an emoji reaction to a message (`room_id`, `sequence_number`, `emoji`) |
| `RemoveReaction` | Remove an emoji reaction from a message (`room_id`, `sequence_number`) |
| `ReadReceipt` | Mark messages as read up to `sequence_number` (`room_id`, `sequence_number`) |
| `SendReply` | Send a reply in a message thread (`room_id`, `parent_sequence_number`, `content`) |

**Server → Client:**

| Message | Description |
|---|---|
| `Pong` | Heartbeat reply |
| `MessageDelivered` | Text message confirmed and stored (`room_id`, `sequence_number`, `sender_id`, `content`, `inserted_at`) |
| `FileDelivered` | File message confirmed and stored (`room_id`, `sequence_number`, `sender_id`, `file_key`, `filename`, `content_type`, `size`, `inserted_at`) |
| `PresenceState` | Current online users in the room (`user_ids`) — pushed on join and on every presence change |
| `TypingEvent` | Typing indicator broadcast with `user_id` injected by the server |
| `ReactionUpdate` | Reaction change broadcast (`room_id`, `sequence_number`, `user_id`, `emoji`, `removed`) |
| `ReadUpdate` | Read receipt broadcast (`room_id`, `user_id`, `sequence_number`) |
| `ReplyDelivered` | Reply confirmed and stored (`room_id`, `parent_sequence_number`, `sequence_number`, `sender_id`, `content`, `inserted_at`) |
| `ThreadUpdate` | Thread reply count updated (`room_id`, `parent_sequence_number`, `reply_count`) |

**Delivery guarantee:** `MessageDelivered` carries a monotonically increasing `sequence_number` per room. On reconnect, the client joins with `last_sequence` and the server replays all missed messages before resuming the live stream. The last acknowledged `sequence_number` is also persisted server-side (via `Ack`) so replay works even without client state.

---

## Development

A [Dev Container](https://containers.dev) configuration is provided at `.devcontainer/`. It includes Elixir 1.17, Bun, `protoc`, `protoc-gen-elixir`, and `protoc-gen-es`.

Compatible with any editor that supports the Dev Container spec. With the CLI:

```bash
# Install the CLI
npm install -g @devcontainers/cli

# Start the container
devcontainer up --workspace-folder .

# Open a shell
devcontainer exec --workspace-folder . bash
```

### Generating Protobuf types

Run from the repo root inside the devcontainer:

```bash
# Elixir
protoc --elixir_out=./core/lib/chat_core/proto proto/messages.proto

# TypeScript (frontend + widget)
protoc --es_out=./frontend/src/proto proto/messages.proto
protoc --es_out=./widget/src/proto proto/messages.proto
```

---

## Testing

### Backend (`core/`)

```bash
cd core
mix test                  # unit tests only (no infra required)
mix test.integration      # starts Docker infra, runs all tests, tears down
mix coveralls             # coverage report (minimum threshold: 80%)
mix credo                 # static analysis
mix dialyzer              # type checking
```

`mix test` excludes `:integration` and `:no_broker` tags by default — no infrastructure needed. `mix test.integration` spins up the test containers defined in `docker-compose.test.yml`, runs the full suite including integration tests, and tears down after.

| Tool | Purpose |
|---|---|
| ExUnit | Test framework |
| Phoenix.ChannelCase | Channel lifecycle testing (connect, join, push, assert_reply, disconnect) |
| Mox | Mocks with explicit behaviour contracts |
| ExMachina | Test data factories |
| StreamData | Property-based testing — sequence numbers and delivery guarantee invariants |
| Credo | Static analysis, style, code smells |
| Dialyxir | Type checking via Dialyzer |
| ExCoveralls | Coverage reports — minimum threshold: 80% |

### Frontend & Backend JS

```bash
cd frontend   # or backend, widget
bun test      # unit tests (Vitest)
bun run e2e   # end-to-end (Playwright)
```

### CI

GitHub Actions runs on every pull request. CodeClimate aggregates coverage and quality gates — a PR is blocked if coverage drops below 80%.

---

## CI/CD

A single workflow (`.github/workflows/ci.yml`) with path-based job filtering. Each job only runs when its relevant paths change — no redundant builds.

```
push / pull_request
        │
        ▼
  detect-changes          ← dorny/paths-filter
  ┌─────┬──────┬────────┬──────────┐
  │     │      │        │          │
  ▼     ▼      ▼        ▼          ▼
core  backend frontend widget   proto
  │                       │
  └───────────────────────┘
    both rebuild when proto/ changes
```

### On pull request

| Job | Triggered when | Steps |
|---|---|---|
| `core` | `core/**` or `proto/**` | test, credo, dialyzer, coverage gate |
| `backend` | `backend/**` | test, type check |
| `frontend` | `frontend/**` | test, build |
| `widget` | `widget/**` or `proto/**` | test, build |

### On release tag (`v*`)

```
tag pushed
    │
    ├── build core image → push to GHCR (ghcr.io/your-username/chat-core)
    │                    → mirror to Docker Hub (optional, via secret)
    │
    └── build widget → publish to npm (@chat/widget)
```

The `proto/messages.proto` dependency is explicit: changes to the protocol trigger rebuilds of both `core` and `widget` — ensuring the published image and the published package are always in sync.

### Secrets required

| Secret | Purpose |
|---|---|
| `GHCR_TOKEN` | GitHub token with `write:packages` — pushes core image to GHCR |
| `NPM_TOKEN` | npm publish token — publishes `@chat/widget` |
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | Optional — mirrors core image to Docker Hub |
| `CC_TEST_REPORTER_ID` | CodeClimate reporter ID for coverage upload |
