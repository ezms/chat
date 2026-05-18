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
  - [Object Storage](#object-storage)
  - [Message Broker](#message-broker)
  - [RabbitMQ Events](#rabbitmq-events)
  - [gRPC Admin API](#grpc-admin-api)
- [Development](#development)
- [Testing](#testing)
- [CI/CD](#cicd)
- [Roadmap](#roadmap)

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
| Search | Meilisearch | Open source search engine, self-hostable, written in Rust. Async indexing via RabbitMQ consumer. ScyllaDB is the primary store — Meilisearch is the index only. *(M7+)* |
| Object storage | MinIO | S3-compatible, self-hostable. Stores files and media. Access via presigned URLs. Replaceable by S3, R2, Oracle Storage via `Chat.Storage` behaviour. *(M5+)* |
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
│   │       ├── database/       # ScyllaDB (Xandra)
│   │       ├── cache/          # Redis
│   │       └── queue/          # RabbitMQ
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
| `MEILISEARCH_URL` | No | _(empty)_ | Enables search feature when set. Requires `search` profile or external instance. |
| `MEILISEARCH_KEY` | No | _(empty)_ | Meilisearch master key. |
| `STORAGE_URL` | No | _(empty)_ | Enables media feature when set. Requires `storage` profile or external instance. |

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
| `search` | Meilisearch | Search feature enabled (M7+) |
| `storage` | MinIO | Media feature enabled (M5+) |
| `demo` | backend + frontend | Standalone deployment / portfolio |

`core` always starts regardless of profiles.

---

## Integration Contracts

### Authentication

The service delegates token validation to the integrator via the `Chat.Auth` behaviour.

```elixir
defmodule Chat.Auth do
  @callback verify(token :: String.t()) ::
    {:ok, user_id :: String.t()} | {:error, reason :: atom()}
end
```

The default implementation validates JWT tokens. To use a different auth mechanism, implement the behaviour and configure it:

```elixir
# config/config.exs
config :chat_core, auth: MyApp.CustomAuth
```

The service receives only a `user_id` from `verify/1`. User profiles, display names, and avatars are the integrator's responsibility.

### Object Storage

The service delegates file storage to the integrator via the `Chat.Storage` behaviour.

```elixir
defmodule Chat.Storage do
  @callback upload(path :: String.t(), content :: binary()) ::
    {:ok, url :: String.t()} | {:error, reason :: atom()}
  @callback presigned_url(path :: String.t()) ::
    {:ok, url :: String.t()} | {:error, reason :: atom()}
  @callback delete(path :: String.t()) ::
    :ok | {:error, reason :: atom()}
end
```

The default implementation uses MinIO. To use S3, R2, Oracle Storage or any other provider:

```elixir
config :chat_core, storage: MyApp.S3Storage
```

### Message Broker

If your system already runs a RabbitMQ instance, point the service to it via `RABBITMQ_URL`. No code changes are required — the service connects to whichever broker is configured.

```bash
RABBITMQ_URL=amqp://user:pass@your-broker:5672
```

Omit the `local-queue` profile when using an external broker.

### RabbitMQ Events

**Published by the service:**

| Exchange | Routing Key | Payload |
|---|---|---|
| `chat.message.inbound` | `workspace.{id}` | `workspaceId, userId, text, requestId, receivedAt` |
| `chat.presence` | `workspace.{id}.presence` | `userId, status (online/offline), channelId` |

**Consumed by the service:**

| Queue | Source | Action |
|---|---|---|
| `chat.notifications.inbound` | any integrating service | Delivers message to user via WebSocket or offline queue |

### gRPC Admin API

Exposed on port `50051`.

```protobuf
service ChatAdmin {
  rpc CreateRoom     (CreateRoomRequest)    returns (Room);
  rpc AddMember      (AddMemberRequest)     returns (Member);
  rpc GetHistory     (HistoryRequest)       returns (stream Message);
  rpc SendSystemMsg  (SystemMessageRequest) returns (Ack);
}
```

### Message Protocol (Protobuf)

Messages are transmitted as **Protobuf over WebSocket**. The `proto/messages.proto` file is the source of truth — it generates types for both Elixir (via `protoc-gen-elixir`) and TypeScript (via `protoc-gen-es`).

```protobuf
message ClientFrame {
  uint64  sequence_number = 1;
  string  channel         = 2;
  oneof   payload {
    SendMessage   send     = 3;
    AckMessage    ack      = 4;
    TypingEvent   typing   = 5;
    PresenceQuery presence = 6;
  }
}

message ServerFrame {
  uint64  sequence_number = 1;
  string  channel         = 2;
  oneof   payload {
    Message       message  = 3;
    Ack           ack      = 4;
    PresenceEvent presence = 5;
    SystemEvent   system   = 6;
  }
}
```

**Delivery guarantee:** each message has a `sequence_number` per channel. On reconnect, the client sends `resume: { channel, last_sequence_number }` and the server replays missed messages in order before resuming the normal stream.

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
mix test                  # full suite
mix test --cover          # with coverage report
mix credo                 # static analysis
mix dialyzer              # type checking
```

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

Integration tests require the infrastructure services. Start them before running:

```bash
docker compose --profile local-db --profile local-cache --profile local-queue up -d
```

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

---

## Roadmap

| Milestone | Description | Complete |
|---|---|---|
| **M0** | Foundation — Elixir project, OTP supervision, ScyllaDB schema, Docker standalone, basic CI | ✅ |
| **M1** | Connection & Auth — UserSocket, Phoenix Channels, Protobuf encoding/decoding, heartbeat | ⬜ |
| **M2** | Messages & Persistence — send/receive, sequence numbers, Message Store, paginated history | ⬜ |
| **M3** | Delivery Guarantees — explicit ack, offline queue, replay on reconnect, at-least-once | ⬜ |
| **M4** | Presence & Rooms — Phoenix Presence, room management, typing indicators, online/offline | ⬜ |
| **M5** | Media & Files — MinIO/S3 via `Chat.Storage`, file message type, presigned URLs | ⬜ |
| **M6** | Extended Features — threads, reactions, read receipts, contact directory | ⬜ |
| **M7** | Search — Meilisearch async indexing, message and contact search API | ⬜ |
| **M8** | Push Notifications — FCM, APNs, Web Push for fully offline users | ⬜ |
| **M9** | Backup & Export — periodic export job to object storage | ⬜ |
