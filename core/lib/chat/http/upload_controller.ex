defmodule Chat.Http.UploadController do
  use Phoenix.Controller, formats: [:json]

  defp storage, do: Application.get_env(:core, :storage_module, Chat.Infra.Storage.Minio)

  def presign_upload(conn, %{"room_id" => room_id, "filename" => filename} = params) do
    content_type = Map.get(params, "content_type", "application/octet-stream")
    ext = filename |> Path.extname() |> String.downcase()
    file_key = "#{room_id}/#{unique_id()}#{ext}"

    case storage().presign_upload(file_key, content_type: content_type) do
      {:ok, result} -> json(conn, result)
      {:error, _} -> conn |> put_status(500) |> json(%{error: "storage unavailable"})
    end
  end

  def presign_download(conn, %{"file_key" => file_key}) do
    case storage().presign_download(file_key) do
      {:ok, url} -> json(conn, %{download_url: url})
      {:error, _} -> conn |> put_status(500) |> json(%{error: "storage unavailable"})
    end
  end

  defp unique_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
