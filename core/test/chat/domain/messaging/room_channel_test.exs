defmodule Chat.Domain.Messaging.RoomChannelTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest

  @endpoint Chat.Endpoint

  @secret "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"
  @signer Joken.Signer.create("HS256", @secret)

  defp make_token(user_id, room_ids) do
    {:ok, token, _} =
      Joken.encode_and_sign(%{"sub" => user_id, "room_ids" => room_ids}, @signer)

    token
  end

  setup do
    Application.put_env(:core, :secret_key_base, @secret)

    {:ok, socket} =
      connect(Chat.Domain.User.Socket, %{"token" => make_token("user_1", ["lobby"])})

    {:ok, _, socket} = subscribe_and_join(socket, "room:lobby")

    %{socket: socket}
  end

  test "joins room successfully", %{socket: socket} do
    assert socket.topic == "room:lobby"
  end

  test "rejects join when room_id is not in token" do
    {:ok, socket} =
      connect(Chat.Domain.User.Socket, %{"token" => make_token("user_1", ["other_room"])})

    assert {:error, %{reason: "unauthorized"}} = subscribe_and_join(socket, "room:lobby")
  end

  test "responds pong to ping", %{socket: socket} do
    payload = Chat.Envelope.encode(%Chat.Envelope{payload: {:ping, %Chat.Ping{}}})
    ref = push(socket, "message", payload)
    assert_reply(ref, :ok, response)
    assert %Chat.Envelope{payload: {:pong, %Chat.Pong{}}} = Chat.Envelope.decode(response)
  end

  test "ignores unknown messages", %{socket: socket} do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:send_message, %Chat.SendMessage{room_id: "lobby", content: "oi"}}
      })

    ref = push(socket, "message", payload)
    refute_reply(ref, :ok)
  end

  test "broadcasts message to other users in room", %{socket: socket} do
    {:ok, socket2} =
      connect(Chat.Domain.User.Socket, %{"token" => make_token("user_2", ["lobby"])})

    {:ok, _, _socket2} = subscribe_and_join(socket2, "room:lobby")

    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:send_message, %Chat.SendMessage{room_id: "lobby", content: "oi"}}
      })

    push(socket, "message", payload)

    assert_broadcast("message", broadcast)

    assert %Chat.Envelope{payload: {:message_delivered, %Chat.MessageDelivered{}}} =
             Chat.Envelope.decode(broadcast)
  end

  test "replays missed messages on reconnect with last_sequence", %{socket: socket} do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:send_message, %Chat.SendMessage{room_id: "lobby", content: "missed"}}
      })

    push(socket, "message", payload)

    {:ok, socket2} =
      connect(Chat.Domain.User.Socket, %{"token" => make_token("user_reconnect", ["lobby"])})

    {:ok, _, _} = subscribe_and_join(socket2, "room:lobby", %{"last_sequence" => 0})

    assert_push("message", _)
  end

  test "terminates cleanly on disconnect", %{socket: socket} do
    Process.flag(:trap_exit, true)
    close(socket)
    assert_receive {:EXIT, _, _}
  end

  test "replays missed messages via stored ack on reconnect" do
    room_id = "room_#{System.unique_integer([:positive])}"
    sender_id = "user_sender_#{System.unique_integer([:positive])}"
    user_offline = "user_offline_#{System.unique_integer([:positive])}"

    {:ok, sender_conn} =
      connect(Chat.Domain.User.Socket, %{"token" => make_token(sender_id, [room_id])})

    {:ok, _, sender_socket} = subscribe_and_join(sender_conn, "room:#{room_id}")

    first_payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:send_message, %Chat.SendMessage{room_id: room_id, content: "first"}}
      })

    push(sender_socket, "message", first_payload)

    :ok = Chat.Infra.Messaging.AckStore.confirm(user_offline, room_id, 1)

    missed_payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:send_message, %Chat.SendMessage{room_id: room_id, content: "missed"}}
      })

    push(sender_socket, "message", missed_payload)

    {:ok, offline_conn} =
      connect(Chat.Domain.User.Socket, %{"token" => make_token(user_offline, [room_id])})

    {:ok, _, _} = subscribe_and_join(offline_conn, "room:#{room_id}")

    assert_push("message", _)
  end
end
