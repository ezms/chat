defmodule Chat.Contracts.Search do
  @callback index(doc :: map()) :: :ok | {:error, term()}
  @callback search(room_id :: String.t(), query :: String.t(), opts :: keyword()) ::
              {:ok, list(map())} | {:error, term()}
end
