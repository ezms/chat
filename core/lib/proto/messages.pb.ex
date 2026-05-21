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

  field(:ack, 5, type: Chat.Ack, oneof: 0)

  field(:typing_event, 6,
    type: Chat.TypingEvent,
    json_name: "typingEvent",
    oneof: 0
  )

  field(:presence_state, 7,
    type: Chat.PresenceState,
    json_name: "presenceState",
    oneof: 0
  )

  field(:send_file, 8, type: Chat.SendFile, json_name: "sendFile", oneof: 0)

  field(:file_delivered, 9,
    type: Chat.FileDelivered,
    json_name: "fileDelivered",
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

defmodule Chat.Ack do
  @moduledoc false

  use Protobuf, full_name: "chat.Ack", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:sequence_number, 1, type: :int64, json_name: "sequenceNumber")
  field(:room_id, 2, type: :string, json_name: "roomId")
end

defmodule Chat.TypingEvent do
  @moduledoc false

  use Protobuf,
    full_name: "chat.TypingEvent",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:user_id, 2, type: :string, json_name: "userId")
  field(:is_typing, 3, type: :bool, json_name: "isTyping")
end

defmodule Chat.PresenceState do
  @moduledoc false

  use Protobuf,
    full_name: "chat.PresenceState",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:user_ids, 1, repeated: true, type: :string, json_name: "userIds")
end

defmodule Chat.SendFile do
  @moduledoc false

  use Protobuf,
    full_name: "chat.SendFile",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:file_key, 2, type: :string, json_name: "fileKey")
  field(:filename, 3, type: :string)
  field(:content_type, 4, type: :string, json_name: "contentType")
  field(:size, 5, type: :int64)
end

defmodule Chat.FileDelivered do
  @moduledoc false

  use Protobuf,
    full_name: "chat.FileDelivered",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:sequence_number, 2, type: :int64, json_name: "sequenceNumber")
  field(:sender_id, 3, type: :string, json_name: "senderId")
  field(:file_key, 4, type: :string, json_name: "fileKey")
  field(:filename, 5, type: :string)
  field(:content_type, 6, type: :string, json_name: "contentType")
  field(:size, 7, type: :int64)
  field(:inserted_at, 8, type: :int64, json_name: "insertedAt")
end
