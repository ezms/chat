defmodule Chat.Core do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Chat.Infra.Database.Supervisor,
      Chat.Infra.Redis.Supervisor,
      {Phoenix.PubSub, name: Chat.PubSub},
      Chat.Endpoint
    ]

    options = [strategy: :one_for_one, name: Chat.Core.Supervisor]
    Supervisor.start_link(children, options)
  end
end
