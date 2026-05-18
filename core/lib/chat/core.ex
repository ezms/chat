defmodule Chat.Core do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Chat.Endpoint,
      {Phoenix.PubSub, name: Chat.PubSub},
      Chat.Infra.Redis.Supervisor
    ]

    options = [strategy: :one_for_one, name: Chat.Core.Supervisor]
    Supervisor.start_link(children, options)
  end
end
