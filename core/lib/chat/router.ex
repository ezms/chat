defmodule Chat.Router do
  use Phoenix.Router

  pipeline :api_auth do
    plug Chat.Http.AuthPlug
  end

  get("/health", Chat.Http.HealthController, :check)

  scope "/", Chat do
    pipe_through :api_auth

    post("/upload/presign", Http.UploadController, :presign_upload)
    get("/files/presign", Http.UploadController, :presign_download)
  end
end
