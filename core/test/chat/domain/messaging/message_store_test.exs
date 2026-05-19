defmodule Chat.Domain.Messaging.MessageStoreTest do
  use ExUnit.Case

  alias Chat.Domain.Messaging.MessageStore
  alias Chat.Domain.Messaging.HistoryStore

  setup do
    %{room_id: "room_#{System.unique_integer([:positive])}"}
  end

  test "inserts a message and returns ok", %{room_id: room_id} do
    assert {:ok, _} = MessageStore.insert(room_id, "user_1", "hello")
  end

  test "sequence_number increments per room", %{room_id: room_id} do
    assert {:ok, _} = MessageStore.insert(room_id, "user_1", "first")
    assert {:ok, _} = MessageStore.insert(room_id, "user_1", "second")

    {:ok, messages} = HistoryStore.get(room_id, 0)
    assert length(messages) == 2
  end
end
