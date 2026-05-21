defmodule Chat.Infra.Queue.ConnectionTest do
  use ExUnit.Case, async: false

  alias Chat.Infra.Queue.Connection

  describe "without broker (unit)" do
    @tag :no_broker
    test "returns not_connected when broker is unavailable" do
      assert {:error, :not_connected} = Connection.channel()
    end
  end

  @moduletag :integration

  describe "with broker (integration)" do
    test "connects and returns a channel" do
      assert :ok = wait_for_connection(20)
      assert {:ok, channel} = Connection.channel()
      assert is_struct(channel, AMQP.Channel)
    end

    test "channel remains available across multiple calls" do
      assert :ok = wait_for_connection(20)
      assert {:ok, ch1} = Connection.channel()
      assert {:ok, ch2} = Connection.channel()
      assert ch1 == ch2
    end
  end

  defp wait_for_connection(0), do: {:error, :timeout}

  defp wait_for_connection(retries) do
    case Connection.channel() do
      {:ok, _} ->
        :ok

      {:error, :not_connected} ->
        Process.sleep(500)
        wait_for_connection(retries - 1)
    end
  end
end
