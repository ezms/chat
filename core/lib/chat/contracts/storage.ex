defmodule Chat.Contracts.Storage do
  @callback presign_upload(file_key :: String.t(), opts :: keyword()) ::
              {:ok, %{upload_url: String.t(), file_key: String.t()}} | {:error, term()}

  @callback presign_download(file_key :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}
end
