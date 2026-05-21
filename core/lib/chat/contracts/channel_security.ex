defmodule Chat.Contracts.ChannelSecurity do
  @callback encode(payload :: binary(), assigns :: map()) :: binary()
  @callback decode(payload :: binary(), assigns :: map()) :: {:ok, binary()} | {:error, term()}
end
