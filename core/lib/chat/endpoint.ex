defmodule Chat.Endpoint do
  use Phoenix.Endpoint, otp_app: :core

  plug Chat.Router

  socket("/socket", Chat.Domain.User.Socket,
    websocket: true,
    longpoll: false
  )
end
