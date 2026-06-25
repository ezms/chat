defmodule Chat.Infra.Redis.SequenceTest do
  use ExUnit.Case

  alias Chat.Infra.Redis.Sequence

  setup do
    id = "seqtest_#{System.unique_integer([:positive])}"
    Redix.command(:redix, ["DEL", "seq:#{id}"])
    %{id: id}
  end

  test "starts at 1 for a new id with empty durable store", %{id: id} do
    assert {:ok, 1} = Sequence.next(id, fn -> 0 end)
    assert {:ok, 2} = Sequence.next(id, fn -> 0 end)
  end

  test "seeds above the durable max on a cold key", %{id: id} do
    assert {:ok, 11} = Sequence.next(id, fn -> 10 end)
    # warm now: the seed is ignored and INCR continues from the reconciled value
    assert {:ok, 12} = Sequence.next(id, fn -> 999 end)
  end

  test "does not consult seed_fn while the key is warm", %{id: id} do
    {:ok, 1} = Sequence.next(id, fn -> 0 end)
    assert {:ok, 2} = Sequence.next(id, fn -> raise "seed_fn called on warm key" end)
  end
end
