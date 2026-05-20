defmodule Chat.Domain.Messaging.RoomChannel do
  use Phoenix.Channel

  alias Chat.Envelope
  alias Chat.Pong
  alias Chat.SendMessage
  alias Chat.MessageDelivered
  alias Chat.TypingEvent
  alias Chat.PresenceState
  alias Chat.Ack
  alias Chat.Domain.Presence
  alias Chat.Infra.Messaging.MessageStore
  alias Chat.Infra.Messaging.HistoryStore
  alias Chat.Infra.Messaging.AckStore
  alias Chat.Infra.Queue.Publisher

  intercept ["presence_diff"]

  @impl true
  def join("room:" <> room_id, %{"last_sequence" => last_sequence}, socket) do
    if room_id in socket.assigns.room_ids do
      send(self(), {:after_join, room_id, last_sequence})
      {:ok, socket}
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
      {:ok, socket}
    end
  end

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
          delivered =
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

          push(socket, "message", delivered)
        end)

      {:error, _} ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_out("presence_diff", _payload, socket) do
    current_users = Presence.list(socket) |> Map.keys()

    push(
      socket,
      "message",
      Envelope.encode(%Envelope{
        payload: {:presence_state, %PresenceState{user_ids: current_users}}
      })
    )

    {:noreply, socket}
  end

  @impl true
  def handle_in("message", payload, socket) do
    case Envelope.decode(payload) do
      %Envelope{payload: {:ping, _}} ->
        response = Envelope.encode(%Envelope{payload: {:pong, %Pong{}}})
        {:reply, {:ok, response}, socket}

      %Envelope{payload: {:send_message, %SendMessage{room_id: room_id, content: content}}} ->
        sender_id = socket.assigns.user_id

        case MessageStore.insert(room_id, sender_id, content) do
          {:ok, sequence_number} ->
            delivered =
              Envelope.encode(%Envelope{
                payload:
                  {:message_delivered,
                   %MessageDelivered{
                     room_id: room_id,
                     sequence_number: sequence_number,
                     sender_id: sender_id,
                     content: content,
                     inserted_at: System.os_time(:millisecond)
                   }}
              })

            broadcast!(socket, "message", delivered)

            Publisher.publish("message.sent", %{
              room_id: room_id,
              sender_id: sender_id,
              sequence_number: sequence_number,
              inserted_at: System.os_time(:millisecond)
            })

            {:noreply, socket}

          {:error, _} ->
            {:reply, {:error, %{}}, socket}
        end

      %Envelope{payload: {:ack, %Ack{room_id: room_id, sequence_number: sequence_number}}} ->
        :ok = AckStore.confirm(socket.assigns.user_id, room_id, sequence_number)
        {:noreply, socket}

      %Envelope{payload: {:typing_event, %TypingEvent{room_id: room_id, is_typing: is_typing}}} ->
        event =
          Envelope.encode(%Envelope{
            payload:
              {:typing_event,
               %TypingEvent{
                 room_id: room_id,
                 user_id: socket.assigns.user_id,
                 is_typing: is_typing
               }}
          })

        broadcast!(socket, "message", event)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

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
