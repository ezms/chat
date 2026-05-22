defmodule Chat.Http.AuthPlugTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  defmodule OkAuth do
    def verify(_token), do: {:ok, %{user_id: "u1", room_ids: ["lobby"]}}
  end

  defmodule FailAuth do
    def verify(_token), do: {:error, :invalid}
  end

  setup do
    Application.put_env(:core, :auth_module, OkAuth)
    on_exit(fn -> Application.delete_env(:core, :auth_module) end)
    :ok
  end

  test "valid Bearer token assigns current_user" do
    opts = Chat.Http.AuthPlug.init([])

    conn =
      conn(:get, "/")
      |> put_req_header("authorization", "Bearer valid_token")
      |> Chat.Http.AuthPlug.call(opts)

    assert conn.assigns[:current_user] == %{user_id: "u1", room_ids: ["lobby"]}
    refute conn.halted
  end

  test "missing Authorization header halts with 401" do
    conn = conn(:get, "/") |> Chat.Http.AuthPlug.call([])

    assert conn.status == 401
    assert conn.halted
    assert Jason.decode!(conn.resp_body) == %{"error" => "unauthorized"}
  end

  test "non-Bearer scheme halts with 401" do
    conn =
      conn(:get, "/")
      |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
      |> Chat.Http.AuthPlug.call([])

    assert conn.status == 401
    assert conn.halted
  end

  test "invalid token halts with 401" do
    Application.put_env(:core, :auth_module, FailAuth)

    conn =
      conn(:get, "/")
      |> put_req_header("authorization", "Bearer bad_token")
      |> Chat.Http.AuthPlug.call([])

    assert conn.status == 401
    assert conn.halted
  end

  test "POST /upload/presign returns 401 without auth" do
    conn = conn(:post, "/upload/presign")
    result = Chat.Router.call(conn, Chat.Router.init([]))
    assert result.status == 401
  end

  test "GET /files/presign returns 401 without auth" do
    conn = conn(:get, "/files/presign?file_key=room/test.jpg")
    result = Chat.Router.call(conn, Chat.Router.init([]))
    assert result.status == 401
  end
end
