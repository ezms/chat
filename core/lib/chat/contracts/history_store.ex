defmodule Chat.Contracts.HistoryStore do
  @callback get(room_id :: String.t(), after_sequence :: integer(), limit :: integer()) ::
              {:ok, list(map())} | {:error, term()}
end
