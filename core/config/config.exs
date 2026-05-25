import Config

config :core, auth_module: Chat.Infra.Auth.Default

config :core, Chat.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: Chat.PubSub

config :core, :meilisearch_url, System.get_env("MEILISEARCH_URL")
config :core, :meilisearch_key, System.get_env("MEILISEARCH_KEY")

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
