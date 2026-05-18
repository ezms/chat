import Config

config :core, auth_module: Chat.Infra.Auth.Default
config :core, Chat.Endpoint, pubsub_server: Chat.PubSub

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
