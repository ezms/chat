defmodule Chat.Domain.Messaging.RoomChannel do
  use Phoenix.Channel

  alias Chat.Envelope
  alias Chat.{Pong, TypingEvent, PresenceState, FileDelivered, MessageDelivered}
  alias Chat.Domain.Presence
  alias Chat.Infra.Messaging.{HistoryStore, AckStore}
  alias Chat.Infra.Queue.Publisher
  alias Chat.Domain.Messaging.Handlers.MessageHandler
  alias Chat.Domain.Messaging.Handlers.ReactionHandler
  alias Chat.Domain.Messaging.Handlers.ThreadHandler
  alias Chat.Domain.Messaging.Handlers.ReadHandler

  intercept(["presence_diff"])

  defp security,
    do: Application.get_env(:core, :channel_security, Chat.Infra.ChannelSecurity.Passthrough)

  @impl true
  def join("room:" <> room_id, %{"last_sequence" => last_sequence}, socket) do
    if room_id in socket.assigns.room_ids do
      send(self(), {:after_join, room_id, last_sequence})
      {:ok, join_reply(socket), socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def join("room:" <> room_id, _params, socket) do
    if room_id not in socket.assigns.room_ids do
      {:error, %{reason: "unauthorized"}}
    else
      send(self(), {:after_join, room_id, nil})
      {:ok, join_reply(socket), socket}
    end
  end

  defp join_reply(%{assigns: %{server_pub_key: key}}), do: %{server_pub_key: key}
  defp join_reply(_socket), do: %{}

  @impl true
  def handle_info({:after_join, room_id, last_sequence}, socket) do
    user_id = socket.assigns.user_id

    {:ok, _} = Presence.track(socket, user_id, %{})

    replay_sequence =
      case last_sequence do
        nil ->
          case AckStore.last_ack(user_id, room_id) do
            {:ok, seq} when seq > 0 -> seq
            _ -> nil
          end

        seq ->
          seq
      end

    if replay_sequence do
      send(self(), {:replay, room_id, replay_sequence})
    end

    Publisher.publish("presence.changed", %{
      room_id: room_id,
      user_id: user_id,
      status: "online"
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:replay, room_id, last_sequence}, socket) do
    case HistoryStore.get(room_id, last_sequence) do
      {:ok, messages} ->
        Enum.each(messages, fn msg ->
          envelope = build_replay_envelope(msg)
          push(socket, "message", security().encode(envelope, socket.assigns))
        end)

      {:error, _} ->
        :ok
    end

    {:noreply, socket}
  end

  defp build_replay_envelope(%{"file_key" => file_key} = msg)
       when is_binary(file_key) and file_key != "" do
    %{"filename" => filename, "content_type" => content_type, "size" => size} =
      Jason.decode!(msg["content"])

    Envelope.encode(%Envelope{
      payload:
        {:file_delivered,
         %FileDelivered{
           room_id: msg["room_id"],
           sequence_number: msg["sequence_number"],
           sender_id: msg["sender_id"],
           file_key: file_key,
           filename: filename,
           content_type: content_type,
           size: size,
           inserted_at: DateTime.to_unix(msg["inserted_at"], :millisecond)
         }}
    })
  end

  defp build_replay_envelope(msg) do
    Envelope.encode(%Envelope{
      payload:
        {:message_delivered,
         %MessageDelivered{
           room_id: msg["room_id"],
           sequence_number: msg["sequence_number"],
           sender_id: msg["sender_id"],
           content: msg["content"],
           inserted_at: DateTime.to_unix(msg["inserted_at"], :millisecond)
         }}
    })
  end

  @impl true
  def handle_out("presence_diff", _payload, socket) do
    current_users = Presence.list(socket) |> Map.keys()

    push(
      socket,
      "message",
      security().encode(
        Envelope.encode(%Envelope{
          payload: {:presence_state, %PresenceState{user_ids: current_users}}
        }),
        socket.assigns
      )
    )

    {:noreply, socket}
  end

  @impl true
  def handle_in("message", raw_payload, socket) do
    with {:ok, payload} <- security().decode(raw_payload, socket.assigns) do
      payload
      |> Envelope.decode()
      |> dispatch(socket)
      |> apply_result(socket)
    else
      {:error, _} -> {:noreply, socket}
    end
  end

  defp dispatch(%Envelope{payload: {:ping, _}}, _socket) do
    {:reply, Envelope.encode(%Envelope{payload: {:pong, %Pong{}}})}
  end

  defp dispatch(%Envelope{payload: {:send_message, msg}}, socket) do
    MessageHandler.handle(msg, socket.assigns)
  end

  defp dispatch(%Envelope{payload: {:send_file, msg}}, socket) do
    MessageHandler.handle(msg, socket.assigns)
  end

  defp dispatch(%Envelope{payload: {:ack, msg}}, socket) do
    MessageHandler.handle(msg, socket.assigns)
  end

  defp dispatch(%Envelope{payload: {:add_reaction, msg}}, socket) do
    ReactionHandler.handle(msg, socket.assigns)
  end

  defp dispatch(%Envelope{payload: {:remove_reaction, msg}}, socket) do
    ReactionHandler.handle(msg, socket.assigns)
  end

  defp dispatch(%Envelope{payload: {:read_receipt, msg}}, socket) do
    ReadHandler.handle(msg, socket.assigns)
  end

  defp dispatch(%Envelope{payload: {:send_reply, msg}}, socket) do
    ThreadHandler.handle(msg, socket.assigns)
  end

  defp dispatch(
         %Envelope{
           payload: {:typing_event, %TypingEvent{room_id: room_id, is_typing: is_typing}}
         },
         socket
       ) do
    {:broadcast,
     Envelope.encode(%Envelope{
       payload:
         {:typing_event,
          %TypingEvent{
            room_id: room_id,
            user_id: socket.assigns.user_id,
            is_typing: is_typing
          }}
     })}
  end

  defp dispatch(_, _socket), do: {:noreply}

  defp apply_result({:broadcast, encoded}, socket) do
    broadcast!(socket, "message", security().encode(encoded, socket.assigns))
    {:noreply, socket}
  end

  defp apply_result({:broadcast_many, encoded_list}, socket) do
    Enum.each(encoded_list, fn enc ->
      broadcast!(socket, "message", security().encode(enc, socket.assigns))
    end)

    {:noreply, socket}
  end

  defp apply_result({:reply, encoded}, socket) do
    {:reply, {:ok, security().encode(encoded, socket.assigns)}, socket}
  end

  defp apply_result({:noreply}, socket), do: {:noreply, socket}

  defp apply_result({:error, _}, socket), do: {:reply, {:error, %{}}, socket}

  @impl true
  def terminate(_reason, socket) do
    room_id = socket.topic |> String.replace_prefix("room:", "")

    Publisher.publish("presence.changed", %{
      room_id: room_id,
      user_id: socket.assigns.user_id,
      status: "offline"
    })

    :ok
  end
end
