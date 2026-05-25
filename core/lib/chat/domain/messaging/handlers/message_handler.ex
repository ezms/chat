defmodule Chat.Domain.Messaging.Handlers.MessageHandler do
  alias Chat.Envelope
  alias Chat.{SendMessage, MessageDelivered, SendFile, FileDelivered, Ack}
  alias Chat.Infra.Messaging.{MessageStore, AckStore}
  alias Chat.Infra.Queue.Publisher
  alias Chat.Infra.Gateway.WebhookNotifier

  def handle(%SendMessage{room_id: room_id, content: content}, %{user_id: sender_id}) do
    case MessageStore.insert(room_id, sender_id, content) do
      {:ok, sequence_number} ->
        now = System.os_time(:millisecond)

        Publisher.publish("message.sent", %{
          room_id: room_id,
          sender_id: sender_id,
          sequence_number: sequence_number,
          inserted_at: now
        })

        Publisher.publish("push.notify", %{
          room_id: room_id,
          sender_id: sender_id,
          sequence_number: sequence_number,
          inserted_at: now
        })

        WebhookNotifier.notify(room_id, sender_id, content, sequence_number)

        {:broadcast,
         Envelope.encode(%Envelope{
           payload:
             {:message_delivered,
              %MessageDelivered{
                room_id: room_id,
                sequence_number: sequence_number,
                sender_id: sender_id,
                content: content,
                inserted_at: System.os_time(:millisecond)
              }}
         })}

      {:error, _} ->
        {:error, :insert_failed}
    end
  end

  def handle(
        %SendFile{
          room_id: room_id,
          file_key: file_key,
          filename: filename,
          content_type: content_type,
          size: size
        },
        %{user_id: sender_id}
      ) do
    case MessageStore.insert_file(room_id, sender_id, file_key, filename, content_type, size) do
      {:ok, sequence_number} ->
        Publisher.publish("push.notify", %{
          room_id: room_id,
          sender_id: sender_id,
          sequence_number: sequence_number,
          inserted_at: System.os_time(:millisecond)
        })

        {:broadcast,
         Envelope.encode(%Envelope{
           payload:
             {:file_delivered,
              %FileDelivered{
                room_id: room_id,
                sequence_number: sequence_number,
                sender_id: sender_id,
                file_key: file_key,
                filename: filename,
                content_type: content_type,
                size: size,
                inserted_at: System.os_time(:millisecond)
              }}
         })}

      {:error, _} ->
        {:error, :insert_failed}
    end
  end

  def handle(%Ack{room_id: room_id, sequence_number: sequence_number}, %{user_id: user_id}) do
    :ok = AckStore.confirm(user_id, room_id, sequence_number)
    {:noreply}
  end
end
