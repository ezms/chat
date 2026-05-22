defmodule Chat.Domain.Messaging.Handlers.ReadHandler do
  alias Chat.Envelope
  alias Chat.{ReadReceipt, ReadUpdate}
  alias Chat.Infra.Messaging.ReadStore

  def handle(%ReadReceipt{room_id: room_id, sequence_number: seq}, %{user_id: user_id}) do
    :ok = ReadStore.mark_read(user_id, room_id, seq)

    {:broadcast,
     Envelope.encode(%Envelope{
       payload:
         {:read_update,
          %ReadUpdate{
            room_id: room_id,
            user_id: user_id,
            sequence_number: seq
          }}
     })}
  end
end
