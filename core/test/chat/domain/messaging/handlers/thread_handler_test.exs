defmodule Chat.Domain.Messaging.Handlers.ThreadHandlerTest do
  use ExUnit.Case

  alias Chat.Domain.Messaging.Handlers.ThreadHandler
  alias Chat.Infra.Scylla.MessageStore
  alias Chat.Envelope

  setup do
    room_id = "room_th_#{System.unique_integer([:positive])}"
    {:ok, parent_seq} = MessageStore.insert(room_id, "author", "parent message")
    %{room_id: room_id, parent_seq: parent_seq}
  end

  test "handle SendReply returns broadcast_many with ReplyDelivered and ThreadUpdate", %{
    room_id: room_id,
    parent_seq: parent_seq
  } do
    assigns = %{user_id: "reply_user"}

    msg = %Chat.SendReply{
      room_id: room_id,
      parent_sequence_number: parent_seq,
      content: "this is a reply"
    }

    assert {:broadcast_many, [reply_enc, thread_enc]} = ThreadHandler.handle(msg, assigns)

    assert %Envelope{payload: {:reply_delivered, reply}} = Envelope.decode(reply_enc)
    assert reply.room_id == room_id
    assert reply.parent_sequence_number == parent_seq
    assert reply.sender_id == "reply_user"
    assert reply.content == "this is a reply"
    assert reply.sequence_number > 0

    assert %Envelope{payload: {:thread_update, thread}} = Envelope.decode(thread_enc)
    assert thread.room_id == room_id
    assert thread.parent_sequence_number == parent_seq
    assert thread.reply_count >= 1
  end

  test "reply_count increments with each reply", %{room_id: room_id, parent_seq: parent_seq} do
    assigns = %{user_id: "reply_user"}
    msg = %Chat.SendReply{room_id: room_id, parent_sequence_number: parent_seq, content: "first"}

    assert {:broadcast_many, [_reply, thread_enc1]} = ThreadHandler.handle(msg, assigns)
    assert %Envelope{payload: {:thread_update, t1}} = Envelope.decode(thread_enc1)

    msg2 = %Chat.SendReply{
      room_id: room_id,
      parent_sequence_number: parent_seq,
      content: "second"
    }

    assert {:broadcast_many, [_reply, thread_enc2]} = ThreadHandler.handle(msg2, assigns)
    assert %Envelope{payload: {:thread_update, t2}} = Envelope.decode(thread_enc2)

    assert t2.reply_count > t1.reply_count
  end
end
