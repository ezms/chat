defmodule Chat.Core do
  use Application

  @impl true
  def start(_type, _args) do
    children = [Chat.Endpoint]

    opts = [strategy: :one_for_one, name: Chat.Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
