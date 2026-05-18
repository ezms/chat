defmodule Chat.Domain.Messaging.StoreTest do
  use ExUnit.Case

  @room_id "test_room_#{System.unique_integer([:positive])}"

  test "inserts a message and returns ok" do
    assert {:ok, _} = Chat.Domain.Messaging.Store.insert(@room_id, "user_1", "hello")
  end

  test "sequence_number increments per room" do
    {:ok, result1} = Chat.Domain.Messaging.Store.insert(@room_id, "user_1", "first")
    {:ok, result2} = Chat.Domain.Messaging.Store.insert(@room_id, "user_1", "second")

    page1 = result1 |> Enum.to_list()
    page2 = result2 |> Enum.to_list()

    assert page1 != page2
  end

  test "get_history returns messages after sequence" do
    Chat.Domain.Messaging.Store.insert(@room_id, "user_1", "msg1")
    Chat.Domain.Messaging.Store.insert(@room_id, "user_1", "msg2")

    {:ok, messages} = Chat.Domain.Messaging.Store.get_history(@room_id, 0)
    assert length(messages) >= 2
  end
end
