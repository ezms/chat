defmodule Chat.Endpoint do
  use Phoenix.Endpoint, otp_app: :core

  plug(Corsica,
    origins: &Chat.Endpoint.allowed_origins/0,
    allow_headers: ["authorization", "content-type"],
    allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  )

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

  def allowed_origins do
    case System.get_env("ALLOWED_ORIGINS", "*") do
      "*" -> "*"
      origins -> String.split(origins, ",", trim: true)
    end
  end
end
