defmodule Chat.Infra.Queue.Connection do
  use GenServer
  require Logger

  @exchange "chat.events"
  @reconnect_interval 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def channel do
    GenServer.call(__MODULE__, :channel)
  end

  def exchange, do: @exchange

  @impl true
  def init(_opts) do
    url = Application.get_env(:core, :rabbitmq_url, "amqp://chat:chat@localhost:5672")
    send(self(), :reconnect)
    {:ok, %{url: url, conn: nil, channel: nil}}
  end

  @impl true
  def handle_call(:channel, _from, %{channel: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:channel, _from, %{channel: channel} = state) do
    {:reply, {:ok, channel}, state}
  end

  @impl true
  def handle_info(:reconnect, %{url: url} = state) do
    case open(url) do
      {:ok, connected} ->
        Logger.info("RabbitMQ connected")
        {:noreply, Map.merge(state, connected)}

      {:error, reason} ->
        Logger.warning("RabbitMQ reconnect failed: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, @reconnect_interval)
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}, reconnecting...")
    Process.send_after(self(), :reconnect, @reconnect_interval)
    {:noreply, %{state | conn: nil, channel: nil}}
  end

  defp open(url) do
    with {:ok, conn} <- AMQP.Connection.open(url),
         {:ok, channel} <- AMQP.Channel.open(conn),
         :ok <- AMQP.Exchange.declare(channel, @exchange, :topic, durable: true) do
      Process.monitor(conn.pid)
      {:ok, %{conn: conn, channel: channel}}
    end
  end
end
