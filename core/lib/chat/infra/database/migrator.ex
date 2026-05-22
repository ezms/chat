defmodule Chat.Infra.Database.Migrator do
  require Logger

  def run(conn) do
    wait_for_connection(conn, 10)

    Enum.each(Chat.Infra.Database.Schema.statements(), fn statement ->
      case Xandra.execute(conn, statement) do
        {:ok, _} ->
          :ok

        {:error, %Xandra.Error{message: msg}} when is_binary(msg) ->
          if String.contains?(msg, "conflicts with an existing column") or
               String.contains?(msg, "already exists") do
            :ok
          else
            Logger.error("Migration failed: #{msg}")
          end

        {:error, error} ->
          Logger.error("Migration failed: #{inspect(error)}")
      end
    end)
  end

  defp wait_for_connection(_conn, 0), do: raise("ScyllaDB not available after retries")

  defp wait_for_connection(conn, retries) do
    case Xandra.execute(conn, "SELECT now() FROM system.local") do
      {:ok, _} ->
        :ok

      {:error, _} ->
        Process.sleep(1000)
        wait_for_connection(conn, retries - 1)
    end
  end
end
