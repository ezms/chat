defmodule Chat.Router do
  use Phoenix.Router

  get "/health", Chat.Http.HealthController, :check
end
