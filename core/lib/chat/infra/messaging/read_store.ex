defmodule Chat.Infra.Messaging.ReadStore do
  def mark_read(user_id, room_id, sequence_number) do
    case Redix.command(:redix, ["SET", "read:#{user_id}:#{room_id}", sequence_number]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def last_read(user_id, room_id) do
    case Redix.command(:redix, ["GET", "read:#{user_id}:#{room_id}"]) do
      {:ok, nil} -> {:ok, 0}
      {:ok, value} -> {:ok, String.to_integer(value)}
      {:error, reason} -> {:error, reason}
    end
  end
end
