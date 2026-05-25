defmodule Chat.Http.AdminController do
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias Chat.{Envelope, MessageDelivered}

  def system_message(conn, %{"room_id" => room_id, "content" => content}) do
    secret = System.get_env("CHAT_ADMIN_SECRET")

    with true <- is_binary(secret) and secret != "",
         ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(token, secret) do
      payload =
        Envelope.encode(%Envelope{
          payload:
            {:message_delivered,
             %MessageDelivered{
               room_id: room_id,
               sequence_number: 0,
               sender_id: "system",
               content: content,
               inserted_at: System.os_time(:millisecond)
             }}
        })

      Chat.Endpoint.broadcast!("room:#{room_id}", "message", {:binary, payload})
      json(conn, %{ok: true})
    else
      _ ->
        conn
        |> put_status(401)
        |> json(%{error: "unauthorized"})
    end
  end

  def system_message(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "room_id and content are required"})
  end
end
