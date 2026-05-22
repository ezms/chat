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

  field(:add_reaction, 10, type: Chat.AddReaction, json_name: "addReaction", oneof: 0)
  field(:remove_reaction, 11, type: Chat.RemoveReaction, json_name: "removeReaction", oneof: 0)

  field(:reaction_update, 12,
    type: Chat.ReactionUpdate,
    json_name: "reactionUpdate",
    oneof: 0
  )

  field(:read_receipt, 13, type: Chat.ReadReceipt, json_name: "readReceipt", oneof: 0)
  field(:read_update, 14, type: Chat.ReadUpdate, json_name: "readUpdate", oneof: 0)
  field(:send_reply, 15, type: Chat.SendReply, json_name: "sendReply", oneof: 0)
  field(:reply_delivered, 16, type: Chat.ReplyDelivered, json_name: "replyDelivered", oneof: 0)
  field(:thread_update, 17, type: Chat.ThreadUpdate, json_name: "threadUpdate", oneof: 0)
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

defmodule Chat.AddReaction do
  @moduledoc false

  use Protobuf,
    full_name: "chat.AddReaction",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:sequence_number, 2, type: :int64, json_name: "sequenceNumber")
  field(:emoji, 3, type: :string)
end

defmodule Chat.RemoveReaction do
  @moduledoc false

  use Protobuf,
    full_name: "chat.RemoveReaction",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:sequence_number, 2, type: :int64, json_name: "sequenceNumber")
end

defmodule Chat.ReactionUpdate do
  @moduledoc false

  use Protobuf,
    full_name: "chat.ReactionUpdate",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:sequence_number, 2, type: :int64, json_name: "sequenceNumber")
  field(:user_id, 3, type: :string, json_name: "userId")
  field(:emoji, 4, type: :string)
  field(:removed, 5, type: :bool)
end

defmodule Chat.ReadReceipt do
  @moduledoc false

  use Protobuf,
    full_name: "chat.ReadReceipt",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:sequence_number, 2, type: :int64, json_name: "sequenceNumber")
end

defmodule Chat.ReadUpdate do
  @moduledoc false

  use Protobuf,
    full_name: "chat.ReadUpdate",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:user_id, 2, type: :string, json_name: "userId")
  field(:sequence_number, 3, type: :int64, json_name: "sequenceNumber")
end

defmodule Chat.SendReply do
  @moduledoc false

  use Protobuf,
    full_name: "chat.SendReply",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:parent_sequence_number, 2, type: :int64, json_name: "parentSequenceNumber")
  field(:content, 3, type: :bytes)
end

defmodule Chat.ReplyDelivered do
  @moduledoc false

  use Protobuf,
    full_name: "chat.ReplyDelivered",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:parent_sequence_number, 2, type: :int64, json_name: "parentSequenceNumber")
  field(:sequence_number, 3, type: :int64, json_name: "sequenceNumber")
  field(:sender_id, 4, type: :string, json_name: "senderId")
  field(:content, 5, type: :bytes)
  field(:inserted_at, 6, type: :int64, json_name: "insertedAt")
end

defmodule Chat.ThreadUpdate do
  @moduledoc false

  use Protobuf,
    full_name: "chat.ThreadUpdate",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:parent_sequence_number, 2, type: :int64, json_name: "parentSequenceNumber")
  field(:reply_count, 3, type: :int64, json_name: "replyCount")
end
