defmodule Chat.Domain.Messaging.Handlers.ReadHandlerTest do
  use ExUnit.Case

  alias Chat.Domain.Messaging.Handlers.ReadHandler
  alias Chat.Infra.Messaging.ReadStore
  alias Chat.Envelope

  test "handle ReadReceipt returns broadcast with ReadUpdate" do
    room_id = "room_rr_#{System.unique_integer([:positive])}"
    assigns = %{user_id: "read_user"}
    msg = %Chat.ReadReceipt{room_id: room_id, sequence_number: 10}

    assert {:broadcast, encoded} = ReadHandler.handle(msg, assigns)
    assert %Envelope{payload: {:read_update, update}} = Envelope.decode(encoded)
    assert update.room_id == room_id
    assert update.user_id == "read_user"
    assert update.sequence_number == 10
  end

  test "handle ReadReceipt persists last read position" do
    room_id = "room_rr_persist_#{System.unique_integer([:positive])}"
    assigns = %{user_id: "read_user_2"}
    msg = %Chat.ReadReceipt{room_id: room_id, sequence_number: 42}

    ReadHandler.handle(msg, assigns)

    assert {:ok, 42} = ReadStore.last_read("read_user_2", room_id)
  end
end
