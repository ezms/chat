defmodule Chat.Infra.Redis.AckStore do
  @behaviour Chat.Contracts.AckStore

  @impl true
  def confirm(user_id, room_id, sequence_number) do
    case Redix.command(:redix, ["SET", "ack:#{user_id}:#{room_id}", sequence_number]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def last_ack(user_id, room_id) do
    case Redix.command(:redix, ["GET", "ack:#{user_id}:#{room_id}"]) do
      {:ok, nil} -> {:ok, 0}
      {:ok, value} -> {:ok, String.to_integer(value)}
      {:error, reason} -> {:error, reason}
    end
  end
end
