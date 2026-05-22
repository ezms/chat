defmodule Chat.Http.UploadControllerTest do
  use ExUnit.Case
  import Plug.Test

  defmodule OkStorage do
    def presign_upload(file_key, _opts),
      do: {:ok, %{upload_url: "http://minio/put/#{file_key}", file_key: file_key}}

    def presign_download(_file_key), do: {:ok, "http://minio/get/file"}
  end

  defmodule FailStorage do
    def presign_upload(_file_key, _opts), do: {:error, :unavailable}
    def presign_download(_file_key), do: {:error, :unavailable}
  end

  setup do
    Application.put_env(:core, :storage_module, OkStorage)
    on_exit(fn -> Application.delete_env(:core, :storage_module) end)
    :ok
  end

  test "presign_upload returns upload_url and file_key" do
    conn = conn(:post, "/upload/presign")

    result =
      Chat.Http.UploadController.presign_upload(conn, %{
        "room_id" => "lobby",
        "filename" => "photo.jpg",
        "content_type" => "image/jpeg"
      })

    assert result.status == 200
    body = Jason.decode!(result.resp_body)
    assert Map.has_key?(body, "upload_url")
    assert Map.has_key?(body, "file_key")
  end

  test "presign_upload uses default content_type when omitted" do
    conn = conn(:post, "/upload/presign")

    result =
      Chat.Http.UploadController.presign_upload(conn, %{
        "room_id" => "lobby",
        "filename" => "doc.pdf"
      })

    assert result.status == 200
  end

  test "presign_upload returns 500 on storage error" do
    Application.put_env(:core, :storage_module, FailStorage)
    conn = conn(:post, "/upload/presign")

    result =
      Chat.Http.UploadController.presign_upload(conn, %{
        "room_id" => "lobby",
        "filename" => "file.jpg"
      })

    assert result.status == 500
    assert Jason.decode!(result.resp_body) == %{"error" => "storage unavailable"}
  end

  test "presign_download returns download_url" do
    conn = conn(:get, "/files/presign")

    result =
      Chat.Http.UploadController.presign_download(conn, %{"file_key" => "lobby/abc.jpg"})

    assert result.status == 200
    body = Jason.decode!(result.resp_body)
    assert Map.has_key?(body, "download_url")
  end

  test "presign_download returns 500 on storage error" do
    Application.put_env(:core, :storage_module, FailStorage)
    conn = conn(:get, "/files/presign")

    result =
      Chat.Http.UploadController.presign_download(conn, %{"file_key" => "lobby/abc.jpg"})

    assert result.status == 500
    assert Jason.decode!(result.resp_body) == %{"error" => "storage unavailable"}
  end
end
