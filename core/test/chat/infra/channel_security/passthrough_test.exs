defmodule Chat.Infra.ChannelSecurity.PassthroughTest do
  use ExUnit.Case, async: true

  alias Chat.Infra.ChannelSecurity.Passthrough

  test "encode returns payload unchanged" do
    payload = <<1, 2, 3>>
    assert Passthrough.encode(payload, %{}) == payload
  end

  test "decode returns {:ok, payload} unchanged" do
    payload = <<1, 2, 3>>
    assert Passthrough.decode(payload, %{}) == {:ok, payload}
  end
end
