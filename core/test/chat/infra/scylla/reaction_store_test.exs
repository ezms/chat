defmodule Chat.Infra.Scylla.ReactionStoreTest do
  use ExUnit.Case

  alias Chat.Infra.Scylla.ReactionStore
  alias Chat.Infra.Scylla.MessageStore

  setup do
    room_id = "room_#{System.unique_integer([:positive])}"
    {:ok, seq} = MessageStore.insert(room_id, "user_1", "hello")
    %{room_id: room_id, sequence_number: seq}
  end

  test "upsert stores a reaction", %{room_id: room_id, sequence_number: seq} do
    assert :ok = ReactionStore.upsert(room_id, seq, "user_1", "👍")
  end

  test "upsert replaces previous reaction from same user", %{
    room_id: room_id,
    sequence_number: seq
  } do
    :ok = ReactionStore.upsert(room_id, seq, "user_1", "👍")
    assert :ok = ReactionStore.upsert(room_id, seq, "user_1", "❤️")
  end

  test "delete removes a reaction", %{room_id: room_id, sequence_number: seq} do
    :ok = ReactionStore.upsert(room_id, seq, "user_1", "👍")
    assert :ok = ReactionStore.delete(room_id, seq, "user_1")
  end

  test "delete is idempotent when reaction does not exist", %{
    room_id: room_id,
    sequence_number: seq
  } do
    assert :ok = ReactionStore.delete(room_id, seq, "user_nobody")
  end
end
