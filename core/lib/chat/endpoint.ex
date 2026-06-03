defmodule Chat.Endpoint do
  use Phoenix.Endpoint, otp_app: :core

  plug(Corsica,
    origins: {Chat.Endpoint, :allowed_origin?, []},
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

  def allowed_origin?(origin) do
    case System.get_env("ALLOWED_ORIGINS", "*") do
      "*" -> true
      origins -> origin in String.split(origins, ",", trim: true)
    end
  end
end
