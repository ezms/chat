const BASE = import.meta.env.VITE_BACKEND_URL ?? "http://localhost:3000";

export interface Room {
    id: string;
    name: string;
}

export interface Session {
    token: string;
    user_id: string;
}

export async function login(username: string): Promise<Session> {
    const res = await fetch(`${BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username }),
    });
    if (!res.ok) throw new Error("Login failed");
    return res.json();
}

export async function getRooms(): Promise<Room[]> {
    const res = await fetch(`${BASE}/rooms`);
    if (!res.ok) throw new Error("Failed to fetch rooms");
    return res.json();
}
