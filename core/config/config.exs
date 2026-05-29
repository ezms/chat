import Config

config :core, auth_module: Chat.Infra.Auth.Default

config :core, message_store: Chat.Infra.Scylla.MessageStore
config :core, history_store: Chat.Infra.Scylla.HistoryStore
config :core, reaction_store: Chat.Infra.Scylla.ReactionStore
config :core, thread_store: Chat.Infra.Scylla.ThreadStore
config :core, ack_store: Chat.Infra.Redis.AckStore
config :core, read_store: Chat.Infra.Redis.ReadStore

config :core, Chat.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: Chat.PubSub

config :core, :meilisearch_url, System.get_env("MEILISEARCH_URL")
config :core, :meilisearch_key, System.get_env("MEILISEARCH_KEY")

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
