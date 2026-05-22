defmodule Chat.Domain.Messaging.Handlers.ReactionHandler do
  alias Chat.Envelope
  alias Chat.{AddReaction, RemoveReaction, ReactionUpdate}
  alias Chat.Infra.Messaging.ReactionStore

  def handle(
        %AddReaction{room_id: room_id, sequence_number: seq, emoji: emoji},
        %{user_id: user_id}
      ) do
    :ok = ReactionStore.upsert(room_id, seq, user_id, emoji)

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
    :ok = ReactionStore.delete(room_id, seq, user_id)

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
