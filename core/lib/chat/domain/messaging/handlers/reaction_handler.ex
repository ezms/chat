defmodule Chat.Domain.Messaging.Handlers.ReactionHandler do
  alias Chat.Envelope
  alias Chat.{AddReaction, RemoveReaction, ReactionUpdate}

  defp reaction_store, do: Application.get_env(:core, :reaction_store, Chat.Infra.Scylla.ReactionStore)

  def handle(
        %AddReaction{room_id: room_id, sequence_number: seq, emoji: emoji},
        %{user_id: user_id}
      ) do
    :ok = reaction_store().upsert(room_id, seq, user_id, emoji)

    {:broadcast,
     Envelope.encode(%Envelope{
       payload:
         {:reaction_update,
          %ReactionUpdate{
            room_id: room_id,
            sequence_number: seq,
            user_id: user_id,
            emoji: emoji,
            removed: false
          }}
     })}
  end

  def handle(%RemoveReaction{room_id: room_id, sequence_number: seq}, %{user_id: user_id}) do
    :ok = reaction_store().delete(room_id, seq, user_id)

    {:broadcast,
     Envelope.encode(%Envelope{
       payload:
         {:reaction_update,
          %ReactionUpdate{
            room_id: room_id,
            sequence_number: seq,
            user_id: user_id,
            emoji: "",
            removed: true
          }}
     })}
  end
end
