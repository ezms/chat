defmodule Chat.Infra.Queue.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Chat.Infra.Queue.Connection, []},
      {Chat.Infra.Queue.Publisher, []}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
