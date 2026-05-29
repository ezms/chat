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

  @impl true
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

  @impl true
  def insert_file(room_id, sender_id, file_key, filename, content_type, size) do
    meta = Jason.encode!(%{filename: filename, content_type: content_type, size: size})

    with {:ok, sequence_number} <- Chat.Infra.Redis.Sequence.next(room_id),
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
end
