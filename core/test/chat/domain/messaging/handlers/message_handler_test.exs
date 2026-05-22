defmodule Chat.Domain.Messaging.Handlers.MessageHandlerTest do
  use ExUnit.Case

  alias Chat.Domain.Messaging.Handlers.MessageHandler
  alias Chat.Envelope

  @assigns %{user_id: "handler_test_user"}

  test "handle SendMessage returns broadcast with MessageDelivered" do
    room_id = "room_mh_#{System.unique_integer([:positive])}"
    msg = %Chat.SendMessage{room_id: room_id, content: "hello handler"}

    assert {:broadcast, encoded} = MessageHandler.handle(msg, @assigns)
    assert %Envelope{payload: {:message_delivered, delivered}} = Envelope.decode(encoded)
    assert delivered.room_id == room_id
    assert delivered.sender_id == "handler_test_user"
    assert delivered.content == "hello handler"
    assert delivered.sequence_number > 0
  end

  test "handle SendFile returns broadcast with FileDelivered" do
    room_id = "room_mh_file_#{System.unique_integer([:positive])}"

    msg = %Chat.SendFile{
      room_id: room_id,
      file_key: "uploads/test.pdf",
      filename: "test.pdf",
      content_type: "application/pdf",
      size: 2048
    }

    assert {:broadcast, encoded} = MessageHandler.handle(msg, @assigns)
    assert %Envelope{payload: {:file_delivered, delivered}} = Envelope.decode(encoded)
    assert delivered.room_id == room_id
    assert delivered.sender_id == "handler_test_user"
    assert delivered.file_key == "uploads/test.pdf"
    assert delivered.filename == "test.pdf"
    assert delivered.size == 2048
    assert delivered.sequence_number > 0
  end

  test "handle Ack stores confirmation and returns noreply" do
    room_id = "room_mh_ack_#{System.unique_integer([:positive])}"
    msg = %Chat.Ack{room_id: room_id, sequence_number: 5}

    assert {:noreply} = MessageHandler.handle(msg, @assigns)
  end
end
