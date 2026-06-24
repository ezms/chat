import { Elysia, t } from "elysia";
import { cors } from "@elysiajs/cors";
import { jwt } from "@elysiajs/jwt";
import { ROOMS } from "./rooms";

const secret = process.env.SECRET_KEY_BASE;
if (!secret) throw new Error("SECRET_KEY_BASE is required");

const app = new Elysia()
    .use(cors())
    .use(jwt({ name: "jwt", secret, alg: "HS256" }))
    .get("/health", () => ({ ok: true }))
    .get("/rooms", () => ROOMS)
    .post(
        "/auth/login",
        async ({ jwt, body }) => {
            const token = await jwt.sign({
                sub: body.username,
                room_ids: ROOMS.map((r) => r.id),
            });
            return { token, user_id: body.username };
        },
        { body: t.Object({ username: t.String({ minLength: 1 }) }) }
    )
    .listen({ port: Number(process.env.PORT ?? 3000), hostname: "0.0.0.0" });

console.log(`backend running on :${app.server?.port}`);
