defmodule Chat.Domain.Messaging.RoomChannel do
  use Phoenix.Channel

  alias Chat.Envelope
  alias Chat.Pong
  alias Chat.SendMessage
  alias Chat.Ack
  alias Chat.Domain.Messaging.MessageStore
  alias Chat.Domain.Messaging.AckStore

  @impl true
  def join("room:" <> room_id, %{"last_sequence" => last_sequence}, socket) do
    send(self(), {:replay, room_id, last_sequence})
    {:ok, socket}
  end

  @impl true
  def join("room:" <> room_id, _params, socket) do
    case AckStore.last_ack(socket.assigns.user_id, room_id) do
      {:ok, last_sequence} when last_sequence > 0 ->
        send(self(), {:replay, room_id, last_sequence})

      _ ->
        :ok
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:replay, room_id, last_sequence}, socket) do
    case Chat.Domain.Messaging.HistoryStore.get(room_id, last_sequence) do
      {:ok, messages} -> Enum.each(messages, fn msg -> push(socket, "message", msg) end)
      {:error, _} -> :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_in("message", payload, socket) do
    case Envelope.decode(payload) do
      %Envelope{payload: {:ping, _}} ->
        response = Envelope.encode(%Envelope{payload: {:pong, %Pong{}}})
        {:reply, {:ok, response}, socket}

      %Envelope{payload: {:send_message, %SendMessage{room_id: room_id, content: content}}} ->
        sender_id = socket.assigns.user_id

        case MessageStore.insert(room_id, sender_id, content) do
          {:ok, _} ->
            broadcast!(socket, "message", payload)
            {:noreply, socket}

          {:error, _} ->
            {:reply, {:error, %{}}, socket}
        end

      %Envelope{payload: {:ack, %Ack{room_id: room_id, sequence_number: sequence_number}}} ->
        :ok = AckStore.confirm(socket.assigns.user_id, room_id, sequence_number)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end
end
