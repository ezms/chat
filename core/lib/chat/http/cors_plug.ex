defmodule Chat.Http.CorsPlug do
  @moduledoc "Wraps Corsica with runtime-configurable origins from ALLOWED_ORIGINS env var."

  def init(_opts), do: []

  def call(conn, _opts) do
    origins =
      case System.get_env("ALLOWED_ORIGINS", "*") do
        "*" -> "*"
        list -> String.split(list, ",", trim: true)
      end

    opts =
      Corsica.init(
        origins: origins,
        allow_headers: ["authorization", "content-type"],
        allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        max_age: 86_400
      )

    Corsica.call(conn, opts)
  end
end
