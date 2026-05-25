defmodule Chat.Infra.Gateway.WebhookNotifier do
  @moduledoc false

  def notify(room_id, sender_id, content, sequence_number) do
    url = Application.get_env(:core, :gateway_webhook_url)
    secret = Application.get_env(:core, :gateway_webhook_secret)

    if url && secret do
      Task.start(fn -> call(url, secret, room_id, sender_id, content, sequence_number) end)
    end

    :ok
  end

  defp call(url, secret, room_id, sender_id, content, sequence_number) do
    text = if String.valid?(content), do: content, else: Base.encode64(content)

    body = Jason.encode!(%{
      room_id: room_id,
      sender_id: sender_id,
      content: text,
      sequence_number: sequence_number
    })

    :hackney.request(
      :post,
      url,
      [{"Authorization", "Bearer #{secret}"}, {"Content-Type", "application/json"}],
      body,
      [:with_body]
    )
  end
end
