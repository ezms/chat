defmodule Chat.Infra.Grpc.Admin do
  use GRPC.Server, service: Chat.Admin.ChatAdmin.Service

  alias Chat.Admin.HistoryMessage
  alias Chat.Admin.SystemAck
  alias Chat.Envelope
  alias Chat.MessageDelivered
  alias Chat.Infra.Messaging.HistoryStore

  def get_history(
        %Chat.Admin.HistoryRequest{room_id: room_id, from_sequence: from_sequence},
        stream
      ) do
    case HistoryStore.get(room_id, from_sequence) do
      {:ok, messages} ->
        Enum.each(messages, fn msg ->
          GRPC.Server.send_reply(stream, %HistoryMessage{
            room_id: msg["room_id"],
            sequence_number: msg["sequence_number"],
            sender_id: msg["sender_id"],
            content: msg["content"],
            inserted_at: DateTime.to_unix(msg["inserted_at"], :millisecond)
          })
        end)

      {:error, _} ->
        raise GRPC.RPCError, status: :internal
    end
  end

  def send_system_msg(
        %Chat.Admin.SystemMessageRequest{room_id: room_id, content: content},
        _stream
      ) do
    payload =
      Envelope.encode(%Envelope{
        payload:
          {:message_delivered,
           %MessageDelivered{
             room_id: room_id,
             sequence_number: 0,
             sender_id: "system",
             content: content,
             inserted_at: System.os_time(:millisecond)
           }}
      })

    Chat.Endpoint.broadcast!("room:#{room_id}", "message", {:binary, payload})
    %SystemAck{}
  end
end
