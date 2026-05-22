defmodule Chat.Infra.Search.Indexer do
  use GenServer
  require Logger

  @queue "chat.search.indexer"
  @reconnect_interval 5_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    send(self(), :setup)
    {:ok, %{channel: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case Chat.Infra.Queue.Connection.channel() do
      {:ok, channel} ->
        AMQP.Queue.declare(channel, @queue, durable: true)
        AMQP.Queue.bind(channel, @queue, "chat.events", routing_key: "message.sent")
        AMQP.Basic.consume(channel, @queue, nil, no_ack: true)
        {:noreply, %{state | channel: channel}}

      {:error, _} ->
        Process.send_after(self(), :setup, @reconnect_interval)
        {:noreply, state}
    end
  end

  def handle_info({:basic_deliver, payload, _meta}, state) do
    with {:ok, doc} <- Jason.decode(payload) do
      search().index(doc)
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp search, do: Application.get_env(:core, :search_module, Chat.Infra.Search.MeilisearchClient)
end
