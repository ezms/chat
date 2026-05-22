defmodule Chat.Http.SearchController do
  use Phoenix.Controller, formats: [:json]

  defp search, do: Application.get_env(:core, :search_module, Chat.Infra.Search.MeilisearchClient)

  def search(conn, %{"room_id" => room_id, "q" => q} = params) do
    if room_id in conn.assigns.current_user.room_ids do
      limit = params |> Map.get("limit", "20") |> String.to_integer()

      case search().search(room_id, q, limit: limit) do
        {:ok, hits} ->
          json(conn, %{hits: hits})

        {:error, _} ->
          conn |> put_status(503) |> json(%{error: "search unavailable"})
      end
    else
      conn |> put_status(403) |> json(%{error: "forbidden"})
    end
  end

  def search(conn, _params) do
    conn |> put_status(400) |> json(%{error: "missing required params: room_id, q"})
  end
end
