import { ApiError, apiFetch } from "./api";
import { readSse } from "./sse";
import type { Message } from "./types";

export type ChatStreamEvent =
  | { type: "text"; delta: string }
  | { type: "tool_start"; name: string; id: string }
  | { type: "tool_end"; name: string; id: string; isError: boolean }
  | { type: "done"; messageId: string | null }
  | { type: "error"; detail: string };

export const STREAM_INTERRUPTED =
  "Verbindung unterbrochen. Die Antwort wird im Hintergrund trotzdem gespeichert – lade den Chat gleich neu.";

export async function streamChatMessage(
  conversationId: string,
  text: string,
  onEvent: (event: ChatStreamEvent) => void,
): Promise<void> {
  const response = await apiFetch(`/conversations/${conversationId}/messages`, {
    method: "POST",
    body: JSON.stringify({ text }),
    headers: { Accept: "text/event-stream" },
  });
  if (!response.body) throw new ApiError(0, "Keine Antwort vom Server");

  let finished = false;
  try {
    for await (const { event, data } of readSse(response.body)) {
      const payload = (data && typeof data === "object" ? data : {}) as Record<string, unknown>;
      switch (event) {
        case "text":
          onEvent({ type: "text", delta: String(payload.delta ?? "") });
          break;
        case "tool_start":
          onEvent({ type: "tool_start", name: String(payload.name ?? ""), id: String(payload.id ?? "") });
          break;
        case "tool_end":
          onEvent({ type: "tool_end", name: String(payload.name ?? ""), id: String(payload.id ?? ""), isError: Boolean(payload.is_error) });
          break;
        case "done":
          finished = true;
          onEvent({ type: "done", messageId: typeof payload.message_id === "string" ? payload.message_id : null });
          break;
        case "error":
          finished = true;
          onEvent({ type: "error", detail: String(payload.detail ?? "Unbekannter Fehler") });
          break;
      }
    }
  } catch (err) {
    if (!finished) {
      onEvent({ type: "error", detail: STREAM_INTERRUPTED });
      return;
    }
    throw err;
  }
  if (!finished) onEvent({ type: "error", detail: STREAM_INTERRUPTED });
}

export interface ToolChip {
  id: string;
  name: string;
  state: "running" | "ok" | "error";
}

export interface PendingTurn {
  userText: string;
  text: string;
  tools: ToolChip[];
  error: string | null;
  finished: boolean;
}

export function startTurn(userText: string): PendingTurn {
  return { userText, text: "", tools: [], error: null, finished: false };
}

export function applyChatEvent(turn: PendingTurn, event: ChatStreamEvent): PendingTurn {
  switch (event.type) {
    case "text":
      return { ...turn, text: turn.text + event.delta };
    case "tool_start":
      return { ...turn, tools: [...turn.tools, { id: event.id, name: event.name, state: "running" }] };
    case "tool_end":
      return {
        ...turn,
        tools: turn.tools.map((tool) =>
          tool.id === event.id ? { ...tool, state: event.isError ? "error" : "ok" } : tool,
        ),
      };
    case "done":
      return { ...turn, finished: true };
    case "error":
      return { ...turn, finished: true, error: event.detail };
  }
}

interface DisplayMessage {
  id: string;
  role: "user" | "assistant";
  text: string;
  tools: string[];
}

export function toDisplayMessages(messages: Message[]): DisplayMessage[] {
  const result: DisplayMessage[] = [];
  for (const message of messages) {
    const texts: string[] = [];
    const tools: string[] = [];
    message.content.forEach((block, index) => {
      if (block.type === "text" && typeof block.text === "string") {
        // hide the backend "[Jetzt: …]" prefix
        if (message.role === "user" && index === 0 && block.text.startsWith("[Jetzt:")) return;
        if (block.text.trim()) texts.push(block.text);
      } else if (block.type === "tool_use" && typeof block.name === "string") {
        tools.push(block.name);
      }
    });
    if (texts.length === 0 && tools.length === 0) continue;
    result.push({ id: message.id, role: message.role, text: texts.join("\n\n"), tools });
  }
  return result;
}
