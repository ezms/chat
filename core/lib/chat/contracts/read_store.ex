defmodule Chat.Contracts.ReadStore do
  @callback mark_read(user_id :: String.t(), room_id :: String.t(), sequence_number :: integer()) ::
              :ok | {:error, term()}

  @callback last_read(user_id :: String.t(), room_id :: String.t()) ::
              {:ok, integer()} | {:error, term()}
end
