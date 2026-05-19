defmodule Chat.Domain.Messaging.AckStoreTest do
  use ExUnit.Case

  setup do
    user_id = "user_#{System.unique_integer([:positive])}"
    room_id = "room_#{System.unique_integer([:positive])}"
    Redix.command(:redix, ["DEL", "ack:#{user_id}:#{room_id}"])
    %{user_id: user_id, room_id: room_id}
  end

  test "confirm persists and last_ack returns sequence", %{user_id: user_id, room_id: room_id} do
    :ok = Chat.Domain.Messaging.AckStore.confirm(user_id, room_id, 42)
    assert {:ok, 42} = Chat.Domain.Messaging.AckStore.last_ack(user_id, room_id)
  end

  test "last_ack returns 0 when no ack exists", %{user_id: user_id, room_id: room_id} do
    assert {:ok, 0} = Chat.Domain.Messaging.AckStore.last_ack(user_id, room_id)
  end
end
