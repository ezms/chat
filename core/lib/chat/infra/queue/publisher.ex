defmodule Chat.Infra.Queue.Publisher do
  use GenServer

  alias Chat.Infra.Queue.Connection

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def publish(routing_key, payload) when is_map(payload) do
    GenServer.cast(__MODULE__, {:publish, routing_key, payload})
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:publish, routing_key, payload}, state) do
    case Connection.channel() do
      {:ok, channel} ->
        message = Jason.encode!(payload)

        AMQP.Basic.publish(
          channel,
          Connection.exchange(),
          routing_key,
          message,
          content_type: "application/json",
          persistent: true
        )

      {:error, _} ->
        :ok
    end

    {:noreply, state}
  end
end
