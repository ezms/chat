defmodule Chat.Infra.Scylla.ReactionStore do
  @behaviour Chat.Contracts.ReactionStore

  @upsert_query """
  INSERT INTO chat.reactions (room_id, sequence_number, user_id, emoji)
  VALUES (?, ?, ?, ?)
  """

  @delete_query """
  DELETE FROM chat.reactions
  WHERE room_id = ? AND sequence_number = ? AND user_id = ?
  """

  @impl true
  def upsert(room_id, sequence_number, user_id, emoji) do
    case Xandra.execute(:xandra, @upsert_query, [
           {"text", room_id},
           {"bigint", sequence_number},
           {"text", user_id},
           {"text", emoji}
         ]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(room_id, sequence_number, user_id) do
    case Xandra.execute(:xandra, @delete_query, [
           {"text", room_id},
           {"bigint", sequence_number},
           {"text", user_id}
         ]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
