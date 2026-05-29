defmodule Chat.Infra.Scylla.HistoryStore do
  @behaviour Chat.Contracts.HistoryStore

  @history_query """
  SELECT room_id, sequence_number, sender_id, content, inserted_at, file_key
  FROM chat.messages
  WHERE room_id = ?
  AND sequence_number > ?
  LIMIT ?
  """

  @impl true
  def get(room_id, after_sequence, limit \\ 50) do
    case Xandra.execute(:xandra, @history_query, [
           {"text", room_id},
           {"bigint", after_sequence},
           {"int", limit}
         ]) do
      {:ok, page} -> {:ok, Enum.to_list(page)}
      {:error, reason} -> {:error, reason}
    end
  end
end
