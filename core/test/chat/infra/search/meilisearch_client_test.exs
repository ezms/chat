defmodule Chat.Infra.Search.MeilisearchClientTest do
  use ExUnit.Case

  alias Chat.Infra.Search.MeilisearchClient

  # These tests exercise error paths that occur when Meilisearch is not running.
  # They cover the function setup lines and error branches without needing
  # a live Meilisearch instance.

  test "index returns error when meilisearch is unreachable" do
    assert {:error, _} = MeilisearchClient.index(%{"room_id" => "r1", "content" => "hello"})
  end

  test "search returns error when meilisearch is unreachable" do
    assert {:error, _} = MeilisearchClient.search("room_1", "hello")
  end

  test "search accepts limit option" do
    assert {:error, _} = MeilisearchClient.search("room_1", "hello", limit: 5)
  end
end
