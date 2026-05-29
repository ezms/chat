defmodule Chat.Core do
  use Application

  @impl true
  def start(_type, _args) do
    grpc_port = Application.get_env(:core, :grpc_port, 50051)

    children =
      [
        Chat.Infra.Scylla.Supervisor,
        Chat.Infra.Redis.Supervisor,
        Chat.Infra.Queue.Supervisor,
        {Phoenix.PubSub, name: Chat.PubSub},
        Chat.Domain.Presence,
        Chat.Endpoint,
        {GRPC.Client.Supervisor, []},
        {GRPC.Server.Supervisor, endpoint: Chat.Infra.Grpc.Endpoint, port: grpc_port}
      ] ++ search_children()

    options = [strategy: :one_for_one, name: Chat.Core.Supervisor]
    Supervisor.start_link(children, options)
  end

  defp search_children do
    case Application.get_env(:core, :meilisearch_url) do
      nil -> []
      _ -> [{Chat.Infra.Search.Indexer, []}]
    end
  end
end
