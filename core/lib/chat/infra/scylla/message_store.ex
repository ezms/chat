defmodule Chat.Infra.Scylla.MessageStore do
  @behaviour Chat.Contracts.MessageStore

  @insert_query """
  INSERT INTO chat.messages (room_id, sequence_number, sender_id, content, inserted_at)
  VALUES (?, ?, ?, ?, ?)
  """

  @insert_file_query """
  INSERT INTO chat.messages (room_id, sequence_number, sender_id, content, inserted_at, file_key)
  VALUES (?, ?, ?, ?, ?, ?)
  """

  @max_query """
  SELECT sequence_number FROM chat.messages
  WHERE room_id = ?
  ORDER BY sequence_number DESC
  LIMIT 1
  """

  @impl true
  def insert(room_id, sender_id, content) do
    with {:ok, sequence_number} <-
           Chat.Infra.Redis.Sequence.next(room_id, fn -> max_sequence(room_id) end),
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

  @impl true
  def insert_file(room_id, sender_id, file_key, filename, content_type, size) do
    meta = Jason.encode!(%{filename: filename, content_type: content_type, size: size})

    with {:ok, sequence_number} <-
           Chat.Infra.Redis.Sequence.next(room_id, fn -> max_sequence(room_id) end),
         {:ok, _} <-
           Xandra.execute(:xandra, @insert_file_query, [
             {"text", room_id},
             {"bigint", sequence_number},
             {"text", sender_id},
             {"blob", meta},
             {"timestamp", System.os_time(:millisecond)},
             {"text", file_key}
           ]) do
      {:ok, sequence_number}
    end
  end

  defp max_sequence(room_id) do
    page = Xandra.execute!(:xandra, @max_query, [{"text", room_id}])

    case Enum.to_list(page) do
      [%{"sequence_number" => seq} | _] -> seq
      [] -> 0
    end
  end
end
