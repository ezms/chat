defmodule Chat.Infra.Gateway.WebhookNotifier do
  @moduledoc false

  require Logger

  def notify(room_id, sender_id, content, sequence_number) do
    with_config(fn url, secret ->
      Task.start(fn -> call(url, secret, room_id, sender_id, content, sequence_number) end)
    end)
  end

  def notify_file(room_id, sender_id, file_key, filename, mime_type, sequence_number) do
    with_config(fn url, secret ->
      Task.start(fn ->
        call_file(url, secret, room_id, sender_id, file_key, filename, mime_type, sequence_number)
      end)
    end)
  end

  defp with_config(fun) do
    url = Application.get_env(:core, :gateway_webhook_url)
    secret = Application.get_env(:core, :gateway_webhook_secret)
    if url && secret, do: fun.(url, secret)
    :ok
  end

  defp call(url, secret, room_id, sender_id, content, sequence_number) do
    text = if String.valid?(content), do: content, else: Base.encode64(content)

    body =
      Jason.encode!(%{
        room_id: room_id,
        sender_id: sender_id,
        content: text,
        sequence_number: sequence_number
      })

    post(url, secret, body)
  end

  defp call_file(url, secret, room_id, sender_id, file_key, filename, mime_type, sequence_number) do
    bucket = Application.get_env(:core, :storage_bucket, "chat")

    with {:ok, %{body: raw}} <- ExAws.S3.get_object(bucket, file_key) |> ExAws.request() do
      body =
        Jason.encode!(%{
          room_id: room_id,
          sender_id: sender_id,
          blob: Base.encode64(raw),
          filename: filename,
          mime_type: mime_type,
          sequence_number: sequence_number
        })

      post(url, secret, body)
    else
      {:error, reason} ->
        Logger.error("[webhook_notifier] failed to fetch file from storage",
          file_key: file_key,
          reason: inspect(reason)
        )
    end
  end

  defp post(url, secret, body) do
    :hackney.request(
      :post,
      url,
      [{"Authorization", "Bearer #{secret}"}, {"Content-Type", "application/json"}],
      body,
      [:with_body]
    )
  end
end
