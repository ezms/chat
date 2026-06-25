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

  @max_query """
  SELECT sequence_number FROM chat.thread_replies
  WHERE room_id = ? AND parent_sequence_number = ?
  ORDER BY sequence_number DESC
  LIMIT 1
  """

  @impl true
  def insert_reply(room_id, parent_sequence_number, sender_id, content) do
    id = "#{room_id}:thread:#{parent_sequence_number}"

    with {:ok, sequence_number} <-
           Chat.Infra.Redis.Sequence.next(id, fn ->
             max_reply_sequence(room_id, parent_sequence_number)
           end),
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

  defp max_reply_sequence(room_id, parent_sequence_number) do
    page =
      Xandra.execute!(:xandra, @max_query, [
        {"text", room_id},
        {"bigint", parent_sequence_number}
      ])

    case Enum.to_list(page) do
      [%{"sequence_number" => seq} | _] -> seq
      [] -> 0
    end
  end
end
