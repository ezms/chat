defmodule Chat.Domain.Messaging.HistoryStoreTest do
  use ExUnit.Case

  alias Chat.Domain.Messaging.MessageStore
  alias Chat.Domain.Messaging.HistoryStore

  setup do
    %{room_id: "room_#{System.unique_integer([:positive])}"}
  end

  test "returns messages after given sequence", %{room_id: room_id} do
    MessageStore.insert(room_id, "user_1", "msg1")
    MessageStore.insert(room_id, "user_1", "msg2")

    {:ok, messages} = HistoryStore.get(room_id, 0)
    assert length(messages) >= 2
  end
end
