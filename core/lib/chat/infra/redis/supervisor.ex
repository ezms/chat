defmodule Chat.Infra.Redis.Supervisor do
  use Supervisor

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(_options) do
    children = [
      {Redix, name: :redix, host: redis_host(), port: redis_port()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp redis_host do
    Application.get_env(:core, :redis_host, "127.0.0.1")
  end

  defp redis_port do
    Application.get_env(:core, :redis_port, 6379)
  end
end
