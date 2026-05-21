defmodule Chat.Infra.Grpc.Endpoint do
  use GRPC.Endpoint

  run(Chat.Infra.Grpc.Admin)
end
