defmodule Chat.Contracts.ChannelSecurity do
  @callback encode(payload :: binary(), assigns :: map()) :: binary()
  @callback decode(payload :: binary(), assigns :: map()) :: {:ok, binary()} | {:error, term()}
  @callback derive_session_key(client_pub_key :: binary()) ::
              {server_pub_key :: binary(), session_key :: binary()}
end
