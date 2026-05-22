defmodule Chat.Infra.Messaging.ReadStoreTest do
  use ExUnit.Case

  alias Chat.Infra.Messaging.ReadStore

  setup do
    user_id = "user_#{System.unique_integer([:positive])}"
    room_id = "room_#{System.unique_integer([:positive])}"
    Redix.command(:redix, ["DEL", "read:#{user_id}:#{room_id}"])
    %{user_id: user_id, room_id: room_id}
  end

  test "mark_read persists and last_read returns sequence", %{user_id: user_id, room_id: room_id} do
    :ok = ReadStore.mark_read(user_id, room_id, 7)
    assert {:ok, 7} = ReadStore.last_read(user_id, room_id)
  end

  test "last_read returns 0 when nothing stored", %{user_id: user_id, room_id: room_id} do
    assert {:ok, 0} = ReadStore.last_read(user_id, room_id)
  end

  test "mark_read advances to higher sequence", %{user_id: user_id, room_id: room_id} do
    :ok = ReadStore.mark_read(user_id, room_id, 3)
    :ok = ReadStore.mark_read(user_id, room_id, 10)
    assert {:ok, 10} = ReadStore.last_read(user_id, room_id)
  end
end
