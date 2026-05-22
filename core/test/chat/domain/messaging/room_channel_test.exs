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

  test "ignores server-side envelope types (catch-all dispatch)", %{socket: socket} do
    payload = Chat.Envelope.encode(%Chat.Envelope{payload: {:pong, %Chat.Pong{}}})
    ref = push(socket, "message", payload)
    refute_reply(ref, :ok)
  end

  test "ack stores confirmation without reply to sender", %{socket: socket} do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:ack, %Chat.Ack{room_id: "lobby", sequence_number: 1}}
      })

    ref = push(socket, "message", payload)
    refute_reply(ref, :ok)
  end

  test "routes send_message through dispatch and broadcasts MessageDelivered", %{socket: socket} do
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

  test "replays file message on reconnect", %{socket: socket} do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload:
          {:send_file,
           %Chat.SendFile{
             room_id: "lobby",
             file_key: "lobby/replay.jpg",
             filename: "replay.jpg",
             content_type: "image/jpeg",
             size: 512
           }}
      })

    push(socket, "message", payload)
    assert_broadcast("message", _delivered)

    {:ok, socket2} =
      connect(Chat.Domain.User.Socket, %{"token" => make_token("user_replay_file", ["lobby"])})

    {:ok, _, _} = subscribe_and_join(socket2, "room:lobby", %{"last_sequence" => 0})

    replayed =
      Enum.find_value(1..5, fn _ ->
        receive do
          %Phoenix.Socket.Message{event: "message", payload: p} ->
            if match?(%Chat.Envelope{payload: {:file_delivered, _}}, Chat.Envelope.decode(p)),
              do: p

          _ ->
            nil
        after
          500 -> nil
        end
      end)

    assert %Chat.Envelope{payload: {:file_delivered, %Chat.FileDelivered{filename: "replay.jpg"}}} =
             Chat.Envelope.decode(replayed)
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

  test "routes add_reaction through dispatch and broadcasts ReactionUpdate", %{socket: socket} do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload:
          {:add_reaction, %Chat.AddReaction{room_id: "lobby", sequence_number: 1, emoji: "👍"}}
      })

    push(socket, "message", payload)
    assert_broadcast("message", broadcast)
    assert %Chat.Envelope{payload: {:reaction_update, %Chat.ReactionUpdate{removed: false}}} =
             Chat.Envelope.decode(broadcast)
  end

  test "routes remove_reaction through dispatch and broadcasts ReactionUpdate removed", %{
    socket: socket
  } do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:remove_reaction, %Chat.RemoveReaction{room_id: "lobby", sequence_number: 1}}
      })

    push(socket, "message", payload)
    assert_broadcast("message", broadcast)
    assert %Chat.Envelope{payload: {:reaction_update, %Chat.ReactionUpdate{removed: true}}} =
             Chat.Envelope.decode(broadcast)
  end

  test "routes read_receipt through dispatch and broadcasts ReadUpdate", %{socket: socket} do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:read_receipt, %Chat.ReadReceipt{room_id: "lobby", sequence_number: 5}}
      })

    push(socket, "message", payload)
    assert_broadcast("message", broadcast)
    assert %Chat.Envelope{payload: {:read_update, %Chat.ReadUpdate{}}} =
             Chat.Envelope.decode(broadcast)
  end

  test "routes send_reply through dispatch and broadcasts ReplyDelivered + ThreadUpdate", %{
    socket: socket
  } do
    send_msg =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:send_message, %Chat.SendMessage{room_id: "lobby", content: "parent"}}
      })

    push(socket, "message", send_msg)
    assert_broadcast("message", delivered_raw)

    %Chat.Envelope{
      payload: {:message_delivered, %Chat.MessageDelivered{sequence_number: parent_seq}}
    } = Chat.Envelope.decode(delivered_raw)

    reply_payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload:
          {:send_reply,
           %Chat.SendReply{
             room_id: "lobby",
             parent_sequence_number: parent_seq,
             content: "reply"
           }}
      })

    push(socket, "message", reply_payload)
    assert_broadcast("message", reply_raw)
    assert_broadcast("message", thread_raw)
    assert %Chat.Envelope{payload: {:reply_delivered, _}} = Chat.Envelope.decode(reply_raw)
    assert %Chat.Envelope{payload: {:thread_update, _}} = Chat.Envelope.decode(thread_raw)
  end

  test "routes typing_event through dispatch and broadcasts TypingEvent", %{socket: socket} do
    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:typing_event, %Chat.TypingEvent{room_id: "lobby", is_typing: true}}
      })

    push(socket, "message", payload)
    assert_broadcast("message", broadcast)
    assert %Chat.Envelope{payload: {:typing_event, %Chat.TypingEvent{is_typing: true}}} =
             Chat.Envelope.decode(broadcast)
  end

  test "terminates cleanly on disconnect", %{socket: socket} do
    Process.flag(:trap_exit, true)
    close(socket)
    assert_receive {:EXIT, _, _}
  end
end
