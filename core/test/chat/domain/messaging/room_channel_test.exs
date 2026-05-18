defmodule Chat.Domain.Messaging.RoomChannelTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest

  @endpoint Chat.Endpoint

  @secret "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"
  @signer Joken.Signer.create("HS256", @secret)

  setup do
    Application.put_env(:core, :secret_key_base, @secret)

    {:ok, token, _} = Joken.encode_and_sign(%{"sub" => "user_1"}, @signer)
    {:ok, socket} = connect(Chat.Domain.User.Socket, %{"token" => token})
    {:ok, _, socket} = subscribe_and_join(socket, "room:lobby")

    %{socket: socket}
  end

  test "joins room successfully", %{socket: socket} do
    assert socket.topic == "room:lobby"
  end

  test "responds pong to ping", %{socket: socket} do
    payload = Chat.Envelope.encode(%Chat.Envelope{payload: {:ping, %Chat.Ping{}}})
    ref = push(socket, "msg", payload)
    assert_reply ref, :ok, response
    assert %Chat.Envelope{payload: {:pong, %Chat.Pong{}}} = Chat.Envelope.decode(response)
  end

  test "ignores unknown messages", %{socket: socket} do
    payload = Chat.Envelope.encode(%Chat.Envelope{payload: {:send_message, %Chat.SendMessage{room_id: "lobby", content: "oi"}}})
    ref = push(socket, "msg", payload)
    refute_reply ref, :ok
  end
end
