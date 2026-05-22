defmodule Chat.Infra.Storage.MinioTest do
  use ExUnit.Case

  alias Chat.Infra.Storage.Minio

  test "presign_upload returns upload_url and file_key" do
    assert {:ok, %{upload_url: url, file_key: "lobby/photo.jpg"}} =
             Minio.presign_upload("lobby/photo.jpg", content_type: "image/jpeg")

    assert is_binary(url)
    assert String.contains?(url, "photo.jpg")
  end

  test "presign_upload uses default content_type when not provided" do
    assert {:ok, %{upload_url: url, file_key: "room/doc.pdf"}} =
             Minio.presign_upload("room/doc.pdf")

    assert is_binary(url)
    assert String.contains?(url, "doc.pdf")
  end

  test "presign_download returns a signed download URL" do
    assert {:ok, url} = Minio.presign_download("lobby/photo.jpg")
    assert is_binary(url)
    assert String.contains?(url, "photo.jpg")
  end
end
