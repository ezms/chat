<script lang="ts">
    let { onLogin }: { onLogin: (username: string) => Promise<void> } = $props();

    let username = $state("");
    let loading = $state(false);
    let error = $state("");

    async function submit() {
        if (!username.trim()) return;
        loading = true;
        error = "";
        try {
            await onLogin(username.trim());
        } catch {
            error = "Could not connect. Is the server running?";
        } finally {
            loading = false;
        }
    }
</script>

<div class="container">
    <form onsubmit={(e) => { e.preventDefault(); submit(); }}>
        <h1>Chat Demo</h1>
        <input
            type="text"
            placeholder="Enter your username"
            bind:value={username}
            disabled={loading}
            autofocus
        />
        {#if error}
            <p class="error">{error}</p>
        {/if}
        <button type="submit" disabled={loading || !username.trim()}>
            {loading ? "Connecting…" : "Join"}
        </button>
    </form>
</div>

<style>
    .container {
        height: 100dvh;
        display: flex;
        align-items: center;
        justify-content: center;
        background: #0f0f0f;
    }

    form {
        display: flex;
        flex-direction: column;
        gap: 12px;
        width: 300px;
    }

    h1 {
        font-size: 1.4rem;
        color: #fff;
        margin-bottom: 4px;
    }

    input {
        background: #1a1a1a;
        border: 1px solid #2a2a2a;
        border-radius: 6px;
        padding: 10px 12px;
        color: #e0e0e0;
        font-size: 1rem;
        outline: none;
    }

    input:focus {
        border-color: #555;
    }

    button {
        background: #3a7bd5;
        border: none;
        border-radius: 6px;
        padding: 10px;
        color: #fff;
        font-size: 1rem;
        cursor: pointer;
    }

    button:disabled {
        opacity: 0.5;
        cursor: default;
    }

    .error {
        font-size: 0.85rem;
        color: #e06c6c;
    }
</style>
