defmodule Chat.Domain.Messaging.StoreTest do
  use ExUnit.Case

  setup do
    %{room_id: "test_room_#{System.unique_integer([:positive])}"}
  end

  test "inserts a message and returns ok", %{room_id: room_id} do
    assert {:ok, _} = Chat.Domain.Messaging.Store.insert(room_id, "user_1", "hello")
  end

  test "sequence_number increments per room", %{room_id: room_id} do
    assert {:ok, _} = Chat.Domain.Messaging.Store.insert(room_id, "user_1", "first")
    assert {:ok, _} = Chat.Domain.Messaging.Store.insert(room_id, "user_1", "second")

    {:ok, messages} = Chat.Domain.Messaging.Store.get_history(room_id, 0)
    assert length(messages) == 2
  end

  test "get_history returns messages after sequence", %{room_id: room_id} do
    Chat.Domain.Messaging.Store.insert(room_id, "user_1", "msg1")
    Chat.Domain.Messaging.Store.insert(room_id, "user_1", "msg2")

    {:ok, messages} = Chat.Domain.Messaging.Store.get_history(room_id, 0)
    assert length(messages) >= 2
  end
end
