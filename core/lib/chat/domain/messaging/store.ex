defmodule Chat.Domain.Messaging.Store do
  @insert_query """
  INSERT INTO chat.messages (room_id, sequence_number, sender_id, content, inserted_at)
  VALUES (?, ?, ?, ?, ?)
  """

  @history_query """
  SELECT room_id, sequence_number, sender_id, content, inserted_at
  FROM chat.messages
  WHERE room_id = ?
  AND sequence_number > ?
  LIMIT ?
  """

  def insert(room_id, sender_id, content) do
    with {:ok, sequence_number} <- Chat.Infra.Redis.Sequence.next(room_id) do
      Xandra.execute(:xandra, @insert_query, [
        room_id,
        sequence_number,
        sender_id,
        content,
        System.os_time(:millisecond)
      ])
    end
  end

  def get_history(room_id, after_sequence, limit \\ 50) do
    case Xandra.execute(:xandra, @history_query, [room_id, after_sequence, limit]) do
      {:ok, page} -> {:ok, Enum.to_list(page)}
      {:error, reason} -> {:error, reason}
    end
  end
end
