defmodule Chat.Domain.Messaging.RoomChannel do
  use Phoenix.Channel

  alias Chat.Envelope
  alias Chat.Pong
  alias Chat.SendMessage

  @impl true
  def join("room:" <> _room_id, _params, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("message", payload, socket) do
    case Envelope.decode(payload) do
      %Envelope{payload: {:ping, _}} ->
        response = Envelope.encode(%Envelope{payload: {:pong, %Pong{}}})
        {:reply, {:ok, response}, socket}

      %Envelope{payload: {:send_message, %SendMessage{room_id: room_id, content: content}}} ->
        sender_id = socket.assigns.user_id

        case Chat.Domain.Messaging.Store.insert(room_id, sender_id, content) do
          {:ok, _} ->
            broadcast!(socket, "message", payload)
            {:noreply, socket}

          {:error, _} ->
            {:reply, {:error, %{}}, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end
end
