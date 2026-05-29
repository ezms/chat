defmodule Chat.Domain.Messaging.Handlers.ReactionHandlerTest do
  use ExUnit.Case

  alias Chat.Domain.Messaging.Handlers.ReactionHandler
  alias Chat.Infra.Scylla.MessageStore
  alias Chat.Envelope

  setup do
    room_id = "room_rh_#{System.unique_integer([:positive])}"
    {:ok, seq} = MessageStore.insert(room_id, "user_seed", "seed message")
    %{room_id: room_id, seq: seq}
  end

  test "handle AddReaction returns broadcast with ReactionUpdate", %{room_id: room_id, seq: seq} do
    assigns = %{user_id: "reaction_user"}
    msg = %Chat.AddReaction{room_id: room_id, sequence_number: seq, emoji: "👍"}

    assert {:broadcast, encoded} = ReactionHandler.handle(msg, assigns)
    assert %Envelope{payload: {:reaction_update, update}} = Envelope.decode(encoded)
    assert update.room_id == room_id
    assert update.sequence_number == seq
    assert update.user_id == "reaction_user"
    assert update.emoji == "👍"
    assert update.removed == false
  end

  test "handle RemoveReaction returns broadcast with ReactionUpdate removed", %{
    room_id: room_id,
    seq: seq
  } do
    assigns = %{user_id: "reaction_user"}
    :ok = Chat.Infra.Scylla.ReactionStore.upsert(room_id, seq, "reaction_user", "👎")

    msg = %Chat.RemoveReaction{room_id: room_id, sequence_number: seq}

    assert {:broadcast, encoded} = ReactionHandler.handle(msg, assigns)
    assert %Envelope{payload: {:reaction_update, update}} = Envelope.decode(encoded)
    assert update.room_id == room_id
    assert update.sequence_number == seq
    assert update.user_id == "reaction_user"
    assert update.removed == true
  end
end
