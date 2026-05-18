defmodule Chat.Domain.Messaging.RoomChannel do
  use Phoenix.Channel

  @impl true
  def join("room:" <> _room_id, _params, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{response: "pong"}}, socket}
  end
end
