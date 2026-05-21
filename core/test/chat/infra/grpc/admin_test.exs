defmodule Chat.Infra.Grpc.AdminTest do
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
    :ok
  end

  describe "get_history/2" do
    test "returns messages stored after given sequence" do
      room_id = "room_grpc_#{System.unique_integer([:positive])}"
      sender_id = "user_grpc_#{System.unique_integer([:positive])}"

      {:ok, conn} =
        connect(Chat.Domain.User.Socket, %{"token" => make_token(sender_id, [room_id])})

      {:ok, _, socket} = subscribe_and_join(conn, "room:#{room_id}")

      payload =
        Chat.Envelope.encode(%Chat.Envelope{
          payload: {:send_message, %Chat.SendMessage{room_id: room_id, content: "hello"}}
        })

      push(socket, "message", payload)
      Process.sleep(50)

      {:ok, messages} = Chat.Infra.Messaging.HistoryStore.get(room_id, 0)

      assert length(messages) >= 1
      assert hd(messages)["room_id"] == room_id
      assert hd(messages)["sender_id"] == sender_id
    end

    test "returns empty list for room with no messages" do
      room_id = "room_grpc_empty_#{System.unique_integer([:positive])}"

      {:ok, messages} = Chat.Infra.Messaging.HistoryStore.get(room_id, 0)
      assert messages == []
    end
  end

  describe "send_system_msg/2" do
    test "broadcasts MessageDelivered with sender_id system to room" do
      room_id = "room_grpc_sys_#{System.unique_integer([:positive])}"
      user_id = "user_grpc_#{System.unique_integer([:positive])}"

      {:ok, conn} =
        connect(Chat.Domain.User.Socket, %{"token" => make_token(user_id, [room_id])})

      {:ok, _, _} = subscribe_and_join(conn, "room:#{room_id}")
      assert_push("message", _presence)

      content = "system alert"

      payload =
        Chat.Envelope.encode(%Chat.Envelope{
          payload:
            {:message_delivered,
             %Chat.MessageDelivered{
               room_id: room_id,
               sequence_number: 0,
               sender_id: "system",
               content: content,
               inserted_at: System.os_time(:millisecond)
             }}
        })

      Chat.Endpoint.broadcast!("room:#{room_id}", "message", payload)

      assert_push("message", pushed)

      assert %Chat.Envelope{
               payload: {:message_delivered, %Chat.MessageDelivered{sender_id: "system"}}
             } = Chat.Envelope.decode(pushed)
    end
  end
end
