defmodule Chat.Domain.User.Socket do
  use Phoenix.Socket

  channel "room:*", Chat.Domain.Messaging.RoomChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    auth = Application.get_env(:core, :auth_module)

    case auth.verify(token) do
      {:ok, user_id} -> {:ok, assign(socket, :user_id, user_id)}
      {:error, _} -> :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(_socket), do: nil
end
