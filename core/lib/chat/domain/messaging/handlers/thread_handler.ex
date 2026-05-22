defmodule Chat.Domain.Messaging.Handlers.ThreadHandler do
  alias Chat.Envelope
  alias Chat.{SendReply, ReplyDelivered, ThreadUpdate}
  alias Chat.Infra.Messaging.ThreadStore
  alias Chat.Infra.Queue.Publisher

  def handle(
        %SendReply{
          room_id: room_id,
          parent_sequence_number: parent_seq,
          content: content
        },
        %{user_id: sender_id}
      ) do
    with {:ok, sequence_number} <-
           ThreadStore.insert_reply(room_id, parent_seq, sender_id, content),
         {:ok, reply_count} <- ThreadStore.count_replies(room_id, parent_seq) do
      Publisher.publish("push.notify", %{
        room_id: room_id,
        sender_id: sender_id,
        sequence_number: sequence_number,
        inserted_at: System.os_time(:millisecond)
      })
      reply =
        Envelope.encode(%Envelope{
          payload:
            {:reply_delivered,
             %ReplyDelivered{
               room_id: room_id,
               parent_sequence_number: parent_seq,
               sequence_number: sequence_number,
               sender_id: sender_id,
               content: content,
               inserted_at: System.os_time(:millisecond)
             }}
        })

      thread =
        Envelope.encode(%Envelope{
          payload:
            {:thread_update,
             %ThreadUpdate{
               room_id: room_id,
               parent_sequence_number: parent_seq,
               reply_count: reply_count
             }}
        })

      {:broadcast_many, [reply, thread]}
    else
      {:error, _} -> {:error, :insert_failed}
    end
  end
end
