defmodule Chat.Infra.Database.Migrator do
  require Logger

  def run(connection) do
    Enum.each(Chat.Infra.Database.Schema.statements(), fn statement ->
      case Xandra.execute(connection, statement) do
        {:ok, _} -> :ok
        {:error, error} -> Logger.error("Migration failed: #{inspect(error)}")
      end
    end)
  end
end
