defmodule Chat.Contracts.AckStore do
  @callback confirm(user_id :: String.t(), room_id :: String.t(), sequence_number :: integer()) ::
              :ok | {:error, term()}

  @callback last_ack(user_id :: String.t(), room_id :: String.t()) ::
              {:ok, integer()} | {:error, term()}
end
