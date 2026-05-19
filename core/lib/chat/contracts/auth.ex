defmodule Chat.Contracts.Auth do
  @callback verify(token :: String.t()) ::
              {:ok, %{user_id: String.t(), room_ids: [String.t()]}} | {:error, term()}
end
