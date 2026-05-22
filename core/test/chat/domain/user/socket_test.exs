defmodule Chat.Domain.User.SocketTest do
  use ExUnit.Case, async: false

  import Phoenix.ChannelTest

  @endpoint Chat.Endpoint

  @secret "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"
  @signer Joken.Signer.create("HS256", @secret)

  setup do
    Application.put_env(:core, :secret_key_base, @secret)
    Application.delete_env(:core, :auth_module)
    :ok
  end

  defp token(claims), do: elem(Joken.encode_and_sign(claims, @signer), 1)

  test "connects with valid token" do
    assert {:ok, socket} =
             connect(Chat.Domain.User.Socket, %{
               "token" => token(%{"sub" => "user_1", "room_ids" => ["lobby"]})
             })

    assert socket.assigns.user_id == "user_1"
    assert socket.assigns.room_ids == ["lobby"]
  end

  test "connects with valid token and client_pub_key, assigns session_key and server_pub_key" do
    {client_pub_key, _client_priv_key} = :crypto.generate_key(:ecdh, :x25519)

    assert {:ok, socket} =
             connect(Chat.Domain.User.Socket, %{
               "token" => token(%{"sub" => "user_1", "room_ids" => ["lobby"]}),
               "client_pub_key" => Base.encode64(client_pub_key)
             })

    assert socket.assigns.user_id == "user_1"
    assert is_binary(socket.assigns.session_key)
    assert is_binary(socket.assigns.server_pub_key)
  end

  test "rejects connection with invalid client_pub_key" do
    assert :error =
             connect(Chat.Domain.User.Socket, %{
               "token" => token(%{"sub" => "user_1", "room_ids" => ["lobby"]}),
               "client_pub_key" => "not_valid_base64!!!"
             })
  end

  test "rejects connection without token" do
    assert :error = connect(Chat.Domain.User.Socket, %{})
  end

  test "rejects connection with invalid token" do
    assert :error = connect(Chat.Domain.User.Socket, %{"token" => "invalido"})
  end
end
