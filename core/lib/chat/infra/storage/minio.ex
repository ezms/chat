defmodule Chat.Infra.Storage.Minio do
  @behaviour Chat.Contracts.Storage

  @impl true
  def presign_upload(file_key, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    bucket = Application.get_env(:core, :storage_bucket, "chat")

    case ExAws.S3.presigned_url(ex_aws_config(), :put, bucket, file_key,
           expires_in: 3600,
           query_params: [{"Content-Type", content_type}]
         ) do
      {:ok, url} -> {:ok, %{upload_url: url, file_key: file_key}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def presign_download(file_key, _opts \\ []) do
    bucket = Application.get_env(:core, :storage_bucket, "chat")

    case ExAws.S3.presigned_url(ex_aws_config(), :get, bucket, file_key, expires_in: 3600) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ex_aws_config do
    ExAws.Config.new(:s3)
  end
end
