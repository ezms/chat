defmodule Chat.Http.HealthControllerTest do
  use ExUnit.Case
  import Plug.Test

  test "GET /health returns 200 with status ok" do
    connection = conn(:get, "/health")
    connection = Chat.Router.call(connection, Chat.Router.init([]))

    assert connection.status == 200
    assert Jason.decode!(connection.resp_body) == %{"status" => "ok"}
  end
end
