defmodule Chat.Infra.ChannelSecurity.Passthrough do
  @behaviour Chat.Contracts.ChannelSecurity

  @impl true
  def encode(payload, _assigns), do: payload

  @impl true
  def decode(payload, _assigns), do: {:ok, payload}
end
