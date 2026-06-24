import { Socket } from "phoenix";
import type { Channel } from "phoenix";
import { create, toBinary, fromBinary } from "@bufbuild/protobuf";
import { EnvelopeSchema, type Envelope } from "./proto/messages_pb";

const WS_URL = import.meta.env.VITE_CORE_WS_URL ?? "ws://localhost:4000/socket";

export type { Channel };

export interface ChatSocket {
    join(roomId: string): Channel;
    sendMessage(channel: Channel, roomId: string, content: string): void;
    sendTyping(channel: Channel, roomId: string, isTyping: boolean): void;
    disconnect(): void;
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
    return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

export function createChatSocket(token: string): ChatSocket {
    const socket = new Socket(WS_URL, {
        params: { token },
        binaryType: "arraybuffer",
    });
    socket.connect();

    return {
        join(roomId) {
            return socket.channel(`room:${roomId}`, { last_sequence: 0 });
        },

        sendMessage(channel, roomId, content) {
            const frame = create(EnvelopeSchema, {
                payload: {
                    case: "sendMessage",
                    value: { roomId, content: new TextEncoder().encode(content) },
                },
            });
            channel.push("message", toArrayBuffer(toBinary(EnvelopeSchema, frame)));
        },

        sendTyping(channel, roomId, isTyping) {
            const frame = create(EnvelopeSchema, {
                payload: {
                    case: "typingEvent",
                    value: { roomId, userId: "", isTyping },
                },
            });
            channel.push("message", toArrayBuffer(toBinary(EnvelopeSchema, frame)));
        },

        disconnect() {
            socket.disconnect();
        },
    };
}

export function decodeEnvelope(data: ArrayBuffer): Envelope {
    return fromBinary(EnvelopeSchema, new Uint8Array(data));
}
