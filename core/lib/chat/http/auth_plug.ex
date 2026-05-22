defmodule Chat.Http.AuthPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    auth = Application.get_env(:core, :auth_module, Chat.Infra.Auth.Default)

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- auth.verify(token) do
      assign(conn, :current_user, claims)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
        |> halt()
    end
  end
end
