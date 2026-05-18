defmodule Chat.Domain.Messaging.RoomChannel do
  use Phoenix.Channel

  alias Chat.Envelope
  alias Chat.Pong

  @impl true
  def join("room:" <> _room_id, _params, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("msg", payload, socket) do
    case Envelope.decode(payload) do
      %Envelope{payload: {:ping, _}} ->
        response = Envelope.encode(%Envelope{payload: {:pong, %Pong{}}})
        {:reply, {:ok, response}, socket}

      _ ->
        {:noreply, socket}
    end
  end
end
