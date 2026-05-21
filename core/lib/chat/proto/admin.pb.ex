defmodule Chat.Admin.HistoryRequest do
  @moduledoc false

  use Protobuf,
    full_name: "chat.admin.HistoryRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:from_sequence, 2, type: :int64, json_name: "fromSequence")
end

defmodule Chat.Admin.HistoryMessage do
  @moduledoc false

  use Protobuf,
    full_name: "chat.admin.HistoryMessage",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:sequence_number, 2, type: :int64, json_name: "sequenceNumber")
  field(:sender_id, 3, type: :string, json_name: "senderId")
  field(:content, 4, type: :bytes)
  field(:inserted_at, 5, type: :int64, json_name: "insertedAt")
end

defmodule Chat.Admin.SystemMessageRequest do
  @moduledoc false

  use Protobuf,
    full_name: "chat.admin.SystemMessageRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:room_id, 1, type: :string, json_name: "roomId")
  field(:content, 2, type: :bytes)
end

defmodule Chat.Admin.SystemAck do
  @moduledoc false

  use Protobuf,
    full_name: "chat.admin.SystemAck",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3
end

defmodule Chat.Admin.ChatAdmin.Service do
  @moduledoc false

  use GRPC.Service, name: "chat.admin.ChatAdmin", protoc_gen_elixir_version: "0.16.0"

  rpc(:GetHistory, Chat.Admin.HistoryRequest, stream(Chat.Admin.HistoryMessage))
  rpc(:SendSystemMsg, Chat.Admin.SystemMessageRequest, Chat.Admin.SystemAck)
end

defmodule Chat.Admin.ChatAdmin.Stub do
  @moduledoc false

  use GRPC.Stub, service: Chat.Admin.ChatAdmin.Service
end
