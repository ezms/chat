defmodule Chat.Infra.Queue.PublisherTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "publish/2" do
    test "publishes message to exchange when connected" do
      assert :ok = wait_for_connection(20)

      assert {:ok, channel} = Chat.Infra.Queue.Connection.channel()
      assert is_struct(channel, AMQP.Channel)

      Chat.Infra.Queue.Publisher.publish("message.sent", %{
        room_id: "room_test",
        sender_id: "user_test",
        sequence_number: 1,
        inserted_at: System.os_time(:millisecond)
      })

      Process.sleep(50)
    end

    test "silently drops publish when not connected" do
      Chat.Infra.Queue.Publisher.publish("message.sent", %{room_id: "room_test"})
    end
  end

  defp wait_for_connection(0), do: {:error, :timeout}

  defp wait_for_connection(retries) do
    case Chat.Infra.Queue.Connection.channel() do
      {:ok, _} ->
        :ok

      {:error, :not_connected} ->
        Process.sleep(500)
        wait_for_connection(retries - 1)
    end
  end
end
