defmodule Chat.Domain.Messaging.RoomChannel do
  use Phoenix.Channel

  alias Chat.Envelope
  alias Chat.Pong
  alias Chat.SendMessage
  alias Chat.MessageDelivered
  alias Chat.TypingEvent
  alias Chat.PresenceState
  alias Chat.Ack
  alias Chat.SendFile
  alias Chat.FileDelivered
  alias Chat.AddReaction
  alias Chat.RemoveReaction
  alias Chat.ReactionUpdate
  alias Chat.ReadReceipt
  alias Chat.ReadUpdate
  alias Chat.SendReply
  alias Chat.ReplyDelivered
  alias Chat.ThreadUpdate
  alias Chat.Domain.Presence
  alias Chat.Infra.Messaging.MessageStore
  alias Chat.Infra.Messaging.HistoryStore
  alias Chat.Infra.Messaging.AckStore
  alias Chat.Infra.Messaging.ReactionStore
  alias Chat.Infra.Messaging.ReadStore
  alias Chat.Infra.Messaging.ThreadStore
  alias Chat.Infra.Queue.Publisher

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
      case Envelope.decode(payload) do
        %Envelope{payload: {:ping, _}} ->
          response =
            security().encode(
              Envelope.encode(%Envelope{payload: {:pong, %Pong{}}}),
              socket.assigns
            )

          {:reply, {:ok, response}, socket}

        %Envelope{payload: {:send_message, %SendMessage{room_id: room_id, content: content}}} ->
          sender_id = socket.assigns.user_id

          case MessageStore.insert(room_id, sender_id, content) do
            {:ok, sequence_number} ->
              delivered =
                security().encode(
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
                  }),
                  socket.assigns
                )

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

        %Envelope{
          payload:
            {:send_file,
             %SendFile{
               room_id: room_id,
               file_key: file_key,
               filename: filename,
               content_type: content_type,
               size: size
             }}
        } ->
          sender_id = socket.assigns.user_id

          case MessageStore.insert_file(
                 room_id,
                 sender_id,
                 file_key,
                 filename,
                 content_type,
                 size
               ) do
            {:ok, sequence_number} ->
              delivered =
                security().encode(
                  Envelope.encode(%Envelope{
                    payload:
                      {:file_delivered,
                       %FileDelivered{
                         room_id: room_id,
                         sequence_number: sequence_number,
                         sender_id: sender_id,
                         file_key: file_key,
                         filename: filename,
                         content_type: content_type,
                         size: size,
                         inserted_at: System.os_time(:millisecond)
                       }}
                  }),
                  socket.assigns
                )

              broadcast!(socket, "message", delivered)
              {:noreply, socket}

            {:error, _} ->
              {:reply, {:error, %{}}, socket}
          end

        %Envelope{payload: {:ack, %Ack{room_id: room_id, sequence_number: sequence_number}}} ->
          :ok = AckStore.confirm(socket.assigns.user_id, room_id, sequence_number)
          {:noreply, socket}

        %Envelope{
          payload:
            {:add_reaction,
             %AddReaction{room_id: room_id, sequence_number: sequence_number, emoji: emoji}}
        } ->
          user_id = socket.assigns.user_id
          :ok = ReactionStore.upsert(room_id, sequence_number, user_id, emoji)

          update =
            security().encode(
              Envelope.encode(%Envelope{
                payload:
                  {:reaction_update,
                   %ReactionUpdate{
                     room_id: room_id,
                     sequence_number: sequence_number,
                     user_id: user_id,
                     emoji: emoji,
                     removed: false
                   }}
              }),
              socket.assigns
            )

          broadcast!(socket, "message", update)
          {:noreply, socket}

        %Envelope{
          payload:
            {:remove_reaction,
             %RemoveReaction{room_id: room_id, sequence_number: sequence_number}}
        } ->
          user_id = socket.assigns.user_id
          :ok = ReactionStore.delete(room_id, sequence_number, user_id)

          update =
            security().encode(
              Envelope.encode(%Envelope{
                payload:
                  {:reaction_update,
                   %ReactionUpdate{
                     room_id: room_id,
                     sequence_number: sequence_number,
                     user_id: user_id,
                     emoji: "",
                     removed: true
                   }}
              }),
              socket.assigns
            )

          broadcast!(socket, "message", update)
          {:noreply, socket}

        %Envelope{
          payload:
            {:read_receipt, %ReadReceipt{room_id: room_id, sequence_number: sequence_number}}
        } ->
          user_id = socket.assigns.user_id
          :ok = ReadStore.mark_read(user_id, room_id, sequence_number)

          update =
            security().encode(
              Envelope.encode(%Envelope{
                payload:
                  {:read_update,
                   %ReadUpdate{
                     room_id: room_id,
                     user_id: user_id,
                     sequence_number: sequence_number
                   }}
              }),
              socket.assigns
            )

          broadcast!(socket, "message", update)
          {:noreply, socket}

        %Envelope{
          payload:
            {:send_reply,
             %SendReply{
               room_id: room_id,
               parent_sequence_number: parent_seq,
               content: content
             }}
        } ->
          sender_id = socket.assigns.user_id

          with {:ok, sequence_number} <-
                 ThreadStore.insert_reply(room_id, parent_seq, sender_id, content),
               {:ok, reply_count} <- ThreadStore.count_replies(room_id, parent_seq) do
            reply =
              security().encode(
                Envelope.encode(%Envelope{
                  payload:
                    {:reply_delivered,
                     %ReplyDelivered{
                       room_id: room_id,
                       parent_sequence_number: parent_seq,
                       sequence_number: sequence_number,
                       sender_id: sender_id,
                       content: content,
                       inserted_at: System.os_time(:millisecond)
                     }}
                }),
                socket.assigns
              )

            thread =
              security().encode(
                Envelope.encode(%Envelope{
                  payload:
                    {:thread_update,
                     %ThreadUpdate{
                       room_id: room_id,
                       parent_sequence_number: parent_seq,
                       reply_count: reply_count
                     }}
                }),
                socket.assigns
              )

            broadcast!(socket, "message", reply)
            broadcast!(socket, "message", thread)
            {:noreply, socket}
          else
            {:error, _} -> {:reply, {:error, %{}}, socket}
          end

        %Envelope{payload: {:typing_event, %TypingEvent{room_id: room_id, is_typing: is_typing}}} ->
          event =
            security().encode(
              Envelope.encode(%Envelope{
                payload:
                  {:typing_event,
                   %TypingEvent{
                     room_id: room_id,
                     user_id: socket.assigns.user_id,
                     is_typing: is_typing
                   }}
              }),
              socket.assigns
            )

          broadcast!(socket, "message", event)
          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    else
      {:error, _} -> {:noreply, socket}
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
