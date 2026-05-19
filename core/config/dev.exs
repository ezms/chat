import Config

config :core, :redis_host, System.get_env("REDIS_HOST", "redis")
config :core, :redis_port, String.to_integer(System.get_env("REDIS_PORT", "6379"))

config :core, :scylladb_url, System.get_env("SCYLLADB_HOST", "scylladb") <> ":9042"
