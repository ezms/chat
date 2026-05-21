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
config :core, :rabbitmq_url, System.get_env("RABBITMQ_URL", "amqp://chat:chat@rabbitmq-test:5672")
config :core, :storage_bucket, System.get_env("MINIO_BUCKET", "chat")

config :ex_aws,
  access_key_id: System.get_env("MINIO_ACCESS_KEY", "chatadmin"),
  secret_access_key: System.get_env("MINIO_SECRET_KEY", "changeme"),
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "http://",
  host: System.get_env("MINIO_HOST", "minio-test"),
  port: String.to_integer(System.get_env("MINIO_PORT", "9000"))
