import Config

config :core, Chat.Endpoint,
  secret_key_base: "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx",
  pubsub_server: Chat.PubSub,
  server: false

config :core,
       :secret_key_base,
       "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"

config :core, :scylladb_url, System.get_env("SCYLLADB_HOST", "scylladb") <> ":9042"
config :core, :redis_host, System.get_env("REDIS_HOST", "redis")
config :core, :redis_port, String.to_integer(System.get_env("REDIS_PORT", "6379"))
