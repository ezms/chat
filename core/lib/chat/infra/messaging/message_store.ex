defmodule Chat.Infra.Messaging.MessageStore do
  @insert_query """
  INSERT INTO chat.messages (room_id, sequence_number, sender_id, content, inserted_at)
  VALUES (?, ?, ?, ?, ?)
  """

  def insert(room_id, sender_id, content) do
    with {:ok, sequence_number} <- Chat.Infra.Redis.Sequence.next(room_id),
         {:ok, _} <-
           Xandra.execute(:xandra, @insert_query, [
             {"text", room_id},
             {"bigint", sequence_number},
             {"text", sender_id},
             {"blob", content},
             {"timestamp", System.os_time(:millisecond)}
           ]) do
      {:ok, sequence_number}
    end
  end
end
