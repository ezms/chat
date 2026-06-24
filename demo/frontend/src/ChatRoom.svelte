<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { decodeEnvelope } from "./lib/socket";
    import type { Room, ChatSocket } from "./lib/api";
    import type { Channel } from "phoenix";

    let {
        room,
        socket,
        userId,
    }: { room: Room; socket: ChatSocket; userId: string } = $props();

    interface Message {
        sender_id: string;
        content: string;
        sequence_number: number;
    }

    let messages = $state<Message[]>([]);
    let typingUsers = $state<Set<string>>(new Set());
    let onlineUsers = $state<string[]>([]);
    let input = $state("");
    let channel: Channel | null = null;

    function joinRoom() {
        channel?.leave();
        messages = [];
        typingUsers = new Set();
        onlineUsers = [];

        channel = socket.join(room.id);

        channel
            .join()
            .receive("ok", () => console.log("[channel] joined", room.id))
            .receive("error", (e: unknown) => console.error("[channel] join error", e))
            .receive("timeout", () => console.warn("[channel] join timeout"));

        channel.on("message", (data: ArrayBuffer) => {
            const envelope = decodeEnvelope(data);
            console.log("[channel] envelope", envelope.payload.case, envelope.payload.value);

            if (envelope.payload.case === "messageDelivered") {
                const m = envelope.payload.value;
                messages = [
                    {
                        sender_id: m.senderId,
                        content: new TextDecoder().decode(m.content),
                        sequence_number: Number(m.sequenceNumber),
                    },
                    ...messages,
                ];
            }

            if (envelope.payload.case === "typingEvent") {
                const t = envelope.payload.value;
                if (t.userId === userId) return;
                typingUsers = new Set(typingUsers);
                if (t.isTyping) typingUsers.add(t.userId);
                else typingUsers.delete(t.userId);
                typingUsers = typingUsers;
            }

            if (envelope.payload.case === "presenceState") {
                onlineUsers = envelope.payload.value.userIds;
            }
        });

        channel.join();
    }

    $effect(() => {
        room; // re-join when room changes
        joinRoom();
    });

    onDestroy(() => channel?.leave());

    let typingTimer: ReturnType<typeof setTimeout>;

    function handleInput() {
        if (!channel) return;
        socket.sendTyping(channel, room.id, true);
        clearTimeout(typingTimer);
        typingTimer = setTimeout(() => socket.sendTyping(channel!, room.id, false), 1500);
    }

    function send() {
        if (!input.trim() || !channel) return;
        socket.sendMessage(channel, room.id, input.trim());
        clearTimeout(typingTimer);
        socket.sendTyping(channel, room.id, false);
        input = "";
    }
</script>

<div class="room">
    <header>
        <span># {room.name}</span>
        {#if onlineUsers.length}
            <span class="online">{onlineUsers.length} online</span>
        {/if}
    </header>

    <div class="messages">
        {#each messages as msg (msg.sequence_number)}
            <div class="message" class:own={msg.sender_id === userId}>
                <span class="sender">{msg.sender_id}</span>
                <span class="content">{msg.content}</span>
            </div>
        {/each}
    </div>

    {#if typingUsers.size}
        <p class="typing">{[...typingUsers].join(", ")} typing…</p>
    {/if}

    <form class="composer" onsubmit={(e) => { e.preventDefault(); send(); }}>
        <input
            type="text"
            placeholder="Message #{room.name}"
            bind:value={input}
            oninput={handleInput}
        />
        <button type="submit" disabled={!input.trim()}>Send</button>
    </form>
</div>

<style>
    .room {
        flex: 1;
        display: flex;
        flex-direction: column;
        overflow: hidden;
    }

    header {
        padding: 12px 16px;
        border-bottom: 1px solid #2a2a2a;
        display: flex;
        align-items: center;
        gap: 12px;
        font-weight: 600;
    }

    .online {
        font-size: 0.75rem;
        color: #4caf50;
        font-weight: 400;
    }

    .messages {
        flex: 1;
        overflow-y: auto;
        padding: 12px 16px;
        display: flex;
        flex-direction: column-reverse;
        gap: 8px;
    }

    .message {
        display: flex;
        gap: 8px;
        align-items: baseline;
    }

    .sender {
        font-size: 0.8rem;
        color: #888;
        white-space: nowrap;
    }

    .message.own .sender {
        color: #3a7bd5;
    }

    .content {
        word-break: break-word;
    }

    .typing {
        padding: 4px 16px;
        font-size: 0.8rem;
        color: #666;
        min-height: 24px;
    }

    .composer {
        padding: 12px 16px;
        border-top: 1px solid #2a2a2a;
        display: flex;
        gap: 8px;
    }

    input {
        flex: 1;
        background: #1a1a1a;
        border: 1px solid #2a2a2a;
        border-radius: 6px;
        padding: 8px 12px;
        color: #e0e0e0;
        font-size: 0.95rem;
        outline: none;
    }

    input:focus {
        border-color: #555;
    }

    button {
        background: #3a7bd5;
        border: none;
        border-radius: 6px;
        padding: 8px 16px;
        color: #fff;
        cursor: pointer;
    }

    button:disabled {
        opacity: 0.4;
        cursor: default;
    }
</style>
