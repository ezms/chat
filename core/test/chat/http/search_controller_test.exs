defmodule Chat.Http.SearchControllerTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  @endpoint Chat.Endpoint

  @secret "test_secret_key_base_must_be_at_least_64_chars_long_xxxxxxxxxxxxxxx"
  @signer Joken.Signer.create("HS256", @secret)

  defp make_token(user_id, room_ids) do
    {:ok, token, _} =
      Joken.encode_and_sign(%{"sub" => user_id, "room_ids" => room_ids}, @signer)

    token
  end

  defp auth_conn(room_ids) do
    token = make_token("user_search", room_ids)

    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
  end

  defmodule OkSearch do
    @behaviour Chat.Contracts.Search
    def index(_doc), do: :ok
    def search(_room_id, _query, _opts), do: {:ok, [%{"content" => "hello world"}]}
  end

  defmodule FailSearch do
    @behaviour Chat.Contracts.Search
    def index(_doc), do: {:error, :unavailable}
    def search(_room_id, _query, _opts), do: {:error, :unavailable}
  end

  setup do
    Application.put_env(:core, :secret_key_base, @secret)
    Application.delete_env(:core, :auth_module)
    Application.put_env(:core, :search_module, OkSearch)
    on_exit(fn -> Application.delete_env(:core, :search_module) end)
    :ok
  end

  test "returns hits for authorized room" do
    conn = get(auth_conn(["lobby"]), "/search", %{"room_id" => "lobby", "q" => "hello"})
    assert conn.status == 200
    assert %{"hits" => [%{"content" => "hello world"}]} = Jason.decode!(conn.resp_body)
  end

  test "returns empty hits when no results" do
    Application.put_env(:core, :search_module, OkSearch)
    conn = get(auth_conn(["lobby"]), "/search", %{"room_id" => "lobby", "q" => "nothing"})
    assert conn.status == 200
    assert %{"hits" => _} = Jason.decode!(conn.resp_body)
  end

  test "returns 403 when room_id not in token" do
    conn = get(auth_conn(["other_room"]), "/search", %{"room_id" => "lobby", "q" => "hello"})
    assert conn.status == 403
  end

  test "returns 400 when required params missing" do
    conn = get(auth_conn(["lobby"]), "/search", %{"room_id" => "lobby"})
    assert conn.status == 400
  end

  test "returns 503 when search module is unavailable" do
    Application.put_env(:core, :search_module, FailSearch)
    conn = get(auth_conn(["lobby"]), "/search", %{"room_id" => "lobby", "q" => "hello"})
    assert conn.status == 503
  end
end
