defmodule Chat.Envelope do
  @moduledoc false

  use Protobuf, full_name: "chat.Envelope", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  oneof(:payload, 0)

  field(:ping, 1, type: Chat.Ping, oneof: 0)
  field(:pong, 2, type: Chat.Pong, oneof: 0)
  field(:send_message, 3, type: Chat.SendMessage, json_name: "sendMessage", oneof: 0)

  field(:message_delivered, 4,
    type: Chat.MessageDelivered,
    json_name: "messageDelivered",
    oneof: 0
  )
end

defmodule Chat.Ping do
  @moduledoc false

  use Protobuf, full_name: "chat.Ping", protoc_gen_elixir_version: "0.16.0", syntax: :proto3
end

defmodule Chat.Pong do
  @moduledoc false

  use Protobuf, full_name: "chat.Pong", protoc_gen_elixir_version: "0.16.0", syntax: :proto3
end

defmodule Chat.SendMessage do
  @moduledoc false

  use Protobuf,
    full_name: "chat.SendMessage",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:content, 2, type: :bytes)
end

defmodule Chat.MessageDelivered do
  @moduledoc false

  use Protobuf,
    full_name: "chat.MessageDelivered",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:sequence_number, 2, type: :int64, json_name: "sequenceNumber")
  field(:sender_id, 3, type: :string, json_name: "senderId")
  field(:content, 4, type: :bytes)
  field(:inserted_at, 5, type: :int64, json_name: "insertedAt")
end
