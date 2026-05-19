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
    {:ok, token, _} = Joken.encode_and_sign(%{"sub" => "user_2"}, @signer)
    {:ok, socket2} = connect(Chat.Domain.User.Socket, %{"token" => token})
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

    {:ok, token, _} = Joken.encode_and_sign(%{"sub" => "user_reconnect"}, @signer)
    {:ok, socket2} = connect(Chat.Domain.User.Socket, %{"token" => token})
    {:ok, _, _} = subscribe_and_join(socket2, "room:lobby", %{"last_sequence" => 0})

    assert_push("message", _)
  end

  test "replays missed messages via stored ack on reconnect" do
    room_id = "room_#{System.unique_integer([:positive])}"
    sender_id = "user_sender_#{System.unique_integer([:positive])}"
    user_offline = "user_offline_#{System.unique_integer([:positive])}"

    {:ok, sender_token, _} = Joken.encode_and_sign(%{"sub" => sender_id}, @signer)
    {:ok, sender_conn} = connect(Chat.Domain.User.Socket, %{"token" => sender_token})
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

    {:ok, offline_token, _} = Joken.encode_and_sign(%{"sub" => user_offline}, @signer)
    {:ok, offline_conn} = connect(Chat.Domain.User.Socket, %{"token" => offline_token})
    {:ok, _, _} = subscribe_and_join(offline_conn, "room:#{room_id}")

    assert_push("message", _)
  end

  test "joins without last_sequence and no prior ack does not replay" do
    room_id = "room_#{System.unique_integer([:positive])}"
    user_id = "user_fresh_#{System.unique_integer([:positive])}"

    {:ok, token, _} = Joken.encode_and_sign(%{"sub" => user_id}, @signer)
    {:ok, conn} = connect(Chat.Domain.User.Socket, %{"token" => token})
    {:ok, _, _} = subscribe_and_join(conn, "room:#{room_id}")

    refute_push("message", _)
  end
end
