defmodule Chat.Infra.Redis.Sequence do
  def next(room_id) do
    case Redix.command(:redix, ["INCR", "seq:#{room_id}"]) do
      {:ok, sequence_number} -> {:ok, sequence_number}
      {:error, reason} -> {:error, reason}
    end
  end
end
