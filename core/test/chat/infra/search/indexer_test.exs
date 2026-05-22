defmodule Chat.Infra.Search.IndexerTest do
  use ExUnit.Case, async: false

  alias Chat.Infra.Search.Indexer

  defmodule MockSearch do
    def index(doc) do
      send(:indexer_test, {:indexed, doc})
      :ok
    end

    def search(_, _, _), do: {:ok, []}
  end

  setup do
    Application.put_env(:core, :search_module, MockSearch)
    on_exit(fn -> Application.delete_env(:core, :search_module) end)
    :ok
  end

  test "starts and retries connection when RabbitMQ is not available" do
    assert {:ok, pid} = start_supervised({Indexer, []})
    # GenServer is running (init + handle_info(:setup) error arm executed)
    assert Process.alive?(pid)
  end

  test "processes basic_deliver message and calls search module" do
    Process.register(self(), :indexer_test)

    {:ok, pid} = start_supervised({Indexer, []})

    doc = %{
      "room_id" => "lobby",
      "sender_id" => "u1",
      "content" => "hello",
      "sequence_number" => 1
    }

    send(pid, {:basic_deliver, Jason.encode!(doc), %{}})

    assert_receive {:indexed, %{"room_id" => "lobby", "content" => "hello"}}, 500
  after
    Process.unregister(:indexer_test)
  end

  test "ignores malformed JSON in basic_deliver" do
    {:ok, pid} = start_supervised({Indexer, []})
    send(pid, {:basic_deliver, "not json", %{}})
    Process.sleep(50)
    assert Process.alive?(pid)
  end

  test "ignores unknown messages" do
    {:ok, pid} = start_supervised({Indexer, []})
    send(pid, :unknown_message)
    Process.sleep(50)
    assert Process.alive?(pid)
  end
end
