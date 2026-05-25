import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing"

  config :core, Chat.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: secret_key_base,
    server: true

  config :core, :secret_key_base, secret_key_base

  config :core, :scylladb_url, System.get_env("SCYLLADB_HOST", "scylladb") <> ":9042"

  config :core,
    redis_host: System.get_env("REDIS_HOST", "redis"),
    redis_port: String.to_integer(System.get_env("REDIS_PORT", "6379"))

  config :core, :rabbitmq_url, System.get_env("RABBITMQ_URL", "amqp://chat:chat@rabbitmq:5672")

  config :core, :storage_bucket, System.get_env("MINIO_BUCKET", "chat")

  config :ex_aws,
    access_key_id: System.get_env("MINIO_ACCESS_KEY"),
    secret_access_key: System.get_env("MINIO_SECRET_KEY"),
    region: "us-east-1"

  config :ex_aws, :s3,
    scheme: System.get_env("MINIO_SCHEME", "http://"),
    host: System.get_env("MINIO_HOST", "minio"),
    port: String.to_integer(System.get_env("MINIO_PORT", "9000"))

  config :core, :meilisearch_url, System.get_env("MEILISEARCH_URL")
  config :core, :meilisearch_key, System.get_env("MEILISEARCH_KEY")

  config :core, :grpc_port, String.to_integer(System.get_env("GRPC_PORT", "50051"))

  config :core, :gateway_webhook_url, System.get_env("GATEWAY_WEBHOOK_URL")
  config :core, :gateway_webhook_secret, System.get_env("GATEWAY_WEBHOOK_SECRET")
end
