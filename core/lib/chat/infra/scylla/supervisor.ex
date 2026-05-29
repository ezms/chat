defmodule Chat.Infra.Scylla.Supervisor do
  use Supervisor

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(_options) do
    children = [
      {Xandra,
       name: :xandra, nodes: [Application.get_env(:core, :scylladb_url, "127.0.0.1:9042")]},
      {Task, fn -> Chat.Infra.Scylla.Migrator.run(:xandra) end}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
