defmodule Chat.Infra.Scylla.ThreadStoreTest do
  use ExUnit.Case

  alias Chat.Infra.Scylla.MessageStore
  alias Chat.Infra.Scylla.ThreadStore

  setup do
    room_id = "room_#{System.unique_integer([:positive])}"
    {:ok, parent_seq} = MessageStore.insert(room_id, "user_1", "parent message")
    %{room_id: room_id, parent_seq: parent_seq}
  end

  test "insert_reply returns a sequence_number", %{room_id: room_id, parent_seq: parent_seq} do
    assert {:ok, seq} = ThreadStore.insert_reply(room_id, parent_seq, "user_2", "reply")
    assert is_integer(seq)
  end

  test "sequence_number increments per thread", %{room_id: room_id, parent_seq: parent_seq} do
    {:ok, seq1} = ThreadStore.insert_reply(room_id, parent_seq, "user_2", "first")
    {:ok, seq2} = ThreadStore.insert_reply(room_id, parent_seq, "user_3", "second")
    assert seq2 > seq1
  end

  test "threads are independent per parent message", %{room_id: room_id} do
    {:ok, p1} = MessageStore.insert(room_id, "user_1", "msg a")
    {:ok, p2} = MessageStore.insert(room_id, "user_1", "msg b")

    {:ok, seq_a} = ThreadStore.insert_reply(room_id, p1, "user_2", "reply to a")
    {:ok, seq_b} = ThreadStore.insert_reply(room_id, p2, "user_2", "reply to b")

    assert seq_a == seq_b
  end

  test "count_replies returns 0 for a message with no replies", %{
    room_id: room_id,
    parent_seq: parent_seq
  } do
    assert {:ok, 0} = ThreadStore.count_replies(room_id, parent_seq)
  end

  test "count_replies increments as replies are added", %{
    room_id: room_id,
    parent_seq: parent_seq
  } do
    ThreadStore.insert_reply(room_id, parent_seq, "user_2", "one")
    assert {:ok, 1} = ThreadStore.count_replies(room_id, parent_seq)

    ThreadStore.insert_reply(room_id, parent_seq, "user_3", "two")
    assert {:ok, 2} = ThreadStore.count_replies(room_id, parent_seq)
  end
end
