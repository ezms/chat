defmodule Chat.Endpoint do
  use Phoenix.Endpoint, otp_app: :core

  plug(Chat.Http.CorsPlug)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Chat.Router)

  socket("/socket", Chat.Domain.User.Socket,
    websocket: true,
    longpoll: false
  )
end
