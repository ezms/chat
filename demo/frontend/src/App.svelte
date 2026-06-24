<script lang="ts">
    import { login, getRooms } from "./lib/api";
    import { createChatSocket } from "./lib/socket";
    import type { Room, Session } from "./lib/api";
    import type { ChatSocket } from "./lib/socket";
    import Login from "./Login.svelte";
    import ChatRoom from "./ChatRoom.svelte";

    let session = $state<Session | null>(null);
    let rooms = $state<Room[]>([]);
    let activeRoom = $state<Room | null>(null);
    let chatSocket = $state<ChatSocket | null>(null);

    async function handleLogin(username: string) {
        session = await login(username);
        rooms = await getRooms();
        chatSocket = createChatSocket(session.token);
        activeRoom = rooms[0] ?? null;
    }
</script>

{#if !session}
    <Login onLogin={handleLogin} />
{:else}
    <div class="layout">
        <aside>
            <p class="username">{session.user_id}</p>
            <ul>
                {#each rooms as room}
                    <li>
                        <button
                            class:active={activeRoom?.id === room.id}
                            onclick={() => (activeRoom = room)}
                        >
                            # {room.name}
                        </button>
                    </li>
                {/each}
            </ul>
        </aside>

        {#if activeRoom && chatSocket}
            <ChatRoom room={activeRoom} socket={chatSocket} userId={session.user_id} />
        {/if}
    </div>
{/if}

<style>
    :global(*, *::before, *::after) {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
    }

    :global(body) {
        font-family: system-ui, sans-serif;
        background: #0f0f0f;
        color: #e0e0e0;
        height: 100dvh;
    }

    .layout {
        display: flex;
        height: 100dvh;
    }

    aside {
        width: 220px;
        background: #1a1a1a;
        border-right: 1px solid #2a2a2a;
        padding: 1rem;
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    .username {
        font-size: 0.85rem;
        color: #888;
        padding-bottom: 0.5rem;
        border-bottom: 1px solid #2a2a2a;
    }

    ul {
        list-style: none;
        display: flex;
        flex-direction: column;
        gap: 2px;
    }

    button {
        background: none;
        border: none;
        color: #aaa;
        cursor: pointer;
        padding: 6px 8px;
        border-radius: 4px;
        width: 100%;
        text-align: left;
        font-size: 0.9rem;
    }

    button:hover {
        background: #2a2a2a;
        color: #e0e0e0;
    }

    button.active {
        background: #2a2a2a;
        color: #fff;
    }
</style>
