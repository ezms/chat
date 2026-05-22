defmodule Chat.Domain.User.Socket do
  use Phoenix.Socket

  channel("room:*", Chat.Domain.Messaging.RoomChannel)

  @impl true
  def connect(%{"token" => token, "client_pub_key" => client_pub_key_b64}, socket, connect_info) do
    security =
      Application.get_env(:core, :channel_security, Chat.Infra.ChannelSecurity.Passthrough)

    with {:ok, client_pub_key} <- Base.decode64(client_pub_key_b64),
         {server_pub_key, session_key} <- security.derive_session_key(client_pub_key) do
      connect(%{"token" => token}, socket, connect_info)
      |> case do
        {:ok, socket} ->
          {:ok,
           socket
           |> assign(:session_key, session_key)
           |> assign(:server_pub_key, Base.encode64(server_pub_key))}

        :error ->
          :error
      end
    else
      _ -> :error
    end
  end

  def connect(%{"token" => token}, socket, _connect_info) do
    auth = Application.get_env(:core, :auth_module, Chat.Infra.Auth.Default)

    case auth.verify(token) do
      {:ok, %{user_id: user_id, room_ids: room_ids}} ->
        socket =
          socket
          |> assign(:user_id, user_id)
          |> assign(:room_ids, room_ids)

        {:ok, socket}

      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(_socket), do: nil
end
