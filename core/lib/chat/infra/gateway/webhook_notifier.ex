defmodule Chat.Infra.Gateway.WebhookNotifier do
  @moduledoc false

  def notify(room_id, sender_id, content, sequence_number) do
    with_config(fn url, secret ->
      Task.start(fn -> call(url, secret, room_id, sender_id, content, sequence_number) end)
    end)
  end

  def notify_file(room_id, sender_id, file_key, filename, mime_type, sequence_number) do
    with_config(fn url, secret ->
      Task.start(fn -> call_file(url, secret, room_id, sender_id, file_key, filename, mime_type, sequence_number) end)
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
    body =
      Jason.encode!(%{
        room_id: room_id,
        sender_id: sender_id,
        file_key: file_key,
        filename: filename,
        mime_type: mime_type,
        sequence_number: sequence_number
      })

    post(url, secret, body)
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
