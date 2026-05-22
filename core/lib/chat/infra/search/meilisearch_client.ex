defmodule Chat.Infra.Search.MeilisearchClient do
  @behaviour Chat.Contracts.Search

  @index "messages"

  @impl true
  def index(doc) do
    case post(url("/indexes/#{@index}/documents"), Jason.encode!([doc])) do
      {:ok, status, _} when status in 200..299 -> :ok
      {:ok, status, _} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def search(room_id, query, opts \\ []) do
    body =
      Jason.encode!(%{
        q: query,
        filter: "room_id = \"#{room_id}\"",
        limit: Keyword.get(opts, :limit, 20)
      })

    with {:ok, 200, resp_body} <- post(url("/indexes/#{@index}/search"), body),
         {:ok, %{"hits" => hits}} <- Jason.decode(resp_body) do
      {:ok, hits}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :search_failed}
    end
  end

  defp post(url, body) do
    headers = [{"Content-Type", "application/json"} | auth_headers()]

    with {:ok, status, _, ref} <- :hackney.request(:post, url, headers, body, []),
         {:ok, resp_body} <- :hackney.body(ref) do
      {:ok, status, resp_body}
    end
  end

  defp url(path) do
    base = Application.get_env(:core, :meilisearch_url) || "http://localhost:7700"
    base <> path
  end

  defp auth_headers do
    case Application.get_env(:core, :meilisearch_key) do
      nil -> []
      key -> [{"Authorization", "Bearer #{key}"}]
    end
  end
end
