defmodule Chat.Infra.Scylla.MessageStoreTest do
  use ExUnit.Case

  alias Chat.Infra.Scylla.MessageStore
  alias Chat.Infra.Scylla.HistoryStore

  setup do
    %{room_id: "room_#{System.unique_integer([:positive])}"}
  end

  test "inserts a message and returns sequence_number", %{room_id: room_id} do
    assert {:ok, sequence_number} = MessageStore.insert(room_id, "user_1", "hello")
    assert is_integer(sequence_number)
  end

  test "sequence_number increments per room", %{room_id: room_id} do
    {:ok, first_sequence} = MessageStore.insert(room_id, "user_1", "first")
    assert {:ok, _} = MessageStore.insert(room_id, "user_1", "second")

    {:ok, messages} = HistoryStore.get(room_id, first_sequence - 1)
    assert length(messages) == 2
  end
end
