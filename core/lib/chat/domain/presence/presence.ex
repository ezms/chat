defmodule Chat.Domain.Presence do
  use Phoenix.Presence,
    otp_app: :core,
    pubsub_server: Chat.PubSub
end
