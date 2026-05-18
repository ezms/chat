import Config

config :core, Chat.Endpoint,
  secret_key_base: "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx",
  pubsub_server: Chat.PubSub,
  server: false

config :core,
       :secret_key_base,
       "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"

config :core, :scylladb_url, "scylladb:9042"
config :core, :redis_host, "127.0.0.1"
config :core, :redis_port, 6379
