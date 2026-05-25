defmodule Chat.Domain.PresenceTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest

  @endpoint Chat.Endpoint

  @secret "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"
  @signer Joken.Signer.create("HS256", @secret)

  defp decode_envelope({:binary, data}), do: Chat.Envelope.decode(data)
  defp decode_envelope(data), do: Chat.Envelope.decode(data)

  defp make_token(user_id, room_ids) do
    {:ok, token, _} =
      Joken.encode_and_sign(%{"sub" => user_id, "room_ids" => room_ids}, @signer)

    token
  end

  setup do
    Application.put_env(:core, :secret_key_base, @secret)
    :ok
  end

  test "pushes presence state when user joins" do
    room_id = "room_#{System.unique_integer([:positive])}"

    {:ok, conn} = connect(Chat.Domain.User.Socket, %{"token" => make_token("user_1", [room_id])})
    {:ok, _, _} = subscribe_and_join(conn, "room:#{room_id}")

    assert_push("message", payload)

    assert %Chat.Envelope{payload: {:presence_state, %Chat.PresenceState{user_ids: user_ids}}} =
             decode_envelope(payload)

    assert "user_1" in user_ids
  end

  test "joins without prior ack does not replay history" do
    room_id = "room_#{System.unique_integer([:positive])}"
    user_id = "user_fresh_#{System.unique_integer([:positive])}"

    {:ok, conn} = connect(Chat.Domain.User.Socket, %{"token" => make_token(user_id, [room_id])})
    {:ok, _, _} = subscribe_and_join(conn, "room:#{room_id}")

    assert_push("message", payload)
    assert %Chat.Envelope{payload: {:presence_state, _}} = decode_envelope(payload)

    refute_push("message", _)
  end

  test "pushes updated presence state when second user joins" do
    room_id = "room_#{System.unique_integer([:positive])}"

    {:ok, conn1} = connect(Chat.Domain.User.Socket, %{"token" => make_token("user_a", [room_id])})
    {:ok, _, _} = subscribe_and_join(conn1, "room:#{room_id}")
    assert_push("message", _)

    {:ok, conn2} = connect(Chat.Domain.User.Socket, %{"token" => make_token("user_b", [room_id])})
    {:ok, _, _} = subscribe_and_join(conn2, "room:#{room_id}")

    assert_push("message", user_b_payload)

    assert %Chat.Envelope{payload: {:presence_state, %Chat.PresenceState{user_ids: user_b_ids}}} =
             decode_envelope(user_b_payload)

    assert "user_b" in user_b_ids

    assert_push("message", user_a_diff)

    assert %Chat.Envelope{
             payload: {:presence_state, %Chat.PresenceState{user_ids: user_a_ids}}
           } = decode_envelope(user_a_diff)

    assert "user_a" in user_a_ids
    assert "user_b" in user_a_ids
  end

  test "broadcasts typing_event with user_id to room" do
    room_id = "room_#{System.unique_integer([:positive])}"

    {:ok, conn1} = connect(Chat.Domain.User.Socket, %{"token" => make_token("user_1", [room_id])})
    {:ok, _, socket1} = subscribe_and_join(conn1, "room:#{room_id}")
    assert_push("message", _)

    {:ok, conn2} = connect(Chat.Domain.User.Socket, %{"token" => make_token("user_2", [room_id])})
    {:ok, _, _} = subscribe_and_join(conn2, "room:#{room_id}")
    assert_push("message", _)
    assert_push("message", _)

    payload =
      Chat.Envelope.encode(%Chat.Envelope{
        payload: {:typing_event, %Chat.TypingEvent{room_id: room_id, is_typing: true}}
      })

    push(socket1, "message", payload)

    assert_broadcast("message", broadcast)

    assert %Chat.Envelope{
             payload: {:typing_event, %Chat.TypingEvent{user_id: "user_1", is_typing: true}}
           } = decode_envelope(broadcast)
  end
end
