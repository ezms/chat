defmodule Chat.Infra.Scylla.ThreadStore do
  @behaviour Chat.Contracts.ThreadStore

  @insert_query """
  INSERT INTO chat.thread_replies
    (room_id, parent_sequence_number, sequence_number, sender_id, content, inserted_at)
  VALUES (?, ?, ?, ?, ?, ?)
  """

  @count_query """
  SELECT COUNT(*) FROM chat.thread_replies
  WHERE room_id = ? AND parent_sequence_number = ?
  """

  @impl true
  def insert_reply(room_id, parent_sequence_number, sender_id, content) do
    with {:ok, sequence_number} <-
           Chat.Infra.Redis.Sequence.next("#{room_id}:thread:#{parent_sequence_number}"),
         {:ok, _} <-
           Xandra.execute(:xandra, @insert_query, [
             {"text", room_id},
             {"bigint", parent_sequence_number},
             {"bigint", sequence_number},
             {"text", sender_id},
             {"blob", content},
             {"timestamp", System.os_time(:millisecond)}
           ]) do
      {:ok, sequence_number}
    end
  end

  @impl true
  def count_replies(room_id, parent_sequence_number) do
    case Xandra.execute(:xandra, @count_query, [
           {"text", room_id},
           {"bigint", parent_sequence_number}
         ]) do
      {:ok, page} ->
        count = page |> Enum.to_list() |> hd() |> Map.get("count")
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
