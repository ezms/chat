export const ROOMS = [
    { id: "general", name: "General" },
    { id: "random", name: "Random" },
    { id: "demo", name: "Demo" },
] as const;

export type Room = (typeof ROOMS)[number];
