import { http, HttpResponse } from "msw";
import { makeMessage } from "../test/factories";
import { server } from "../test/server";
import { sseResponse } from "../test/sse";
import { ApiError } from "./api";
import {
  applyChatEvent,
  STREAM_INTERRUPTED,
  startTurn,
  streamChatMessage,
  toDisplayMessages,
  type ChatStreamEvent,
} from "./chat";
import { setToken } from "./token";

beforeEach(() => setToken("t"));

test("streams text, tools and done", async () => {
  let body: unknown;
  server.use(
    http.post("*/api/v1/conversations/c1/messages", async ({ request }) => {
      body = await request.json();
      return sseResponse([
        ["tool_start", { name: "create_item", id: "t1" }],
        ["tool_end", { name: "create_item", id: "t1", is_error: false }],
        ["text", { delta: "✓ " }],
        ["text", { delta: "angelegt" }],
        ["done", { message_id: "m9", usage: {} }],
      ]);
    }),
  );
  const events: ChatStreamEvent[] = [];
  await streamChatMessage("c1", "Milch kaufen", (event) => events.push(event));
  expect(body).toEqual({ text: "Milch kaufen" });
  expect(events).toEqual([
    { type: "tool_start", name: "create_item", id: "t1" },
    { type: "tool_end", name: "create_item", id: "t1", isError: false },
    { type: "text", delta: "✓ " },
    { type: "text", delta: "angelegt" },
    { type: "done", messageId: "m9" },
  ]);
});

test("reports interruption when neither done nor error arrives", async () => {
  server.use(
    http.post("*/api/v1/conversations/c1/messages", () => sseResponse([["text", { delta: "Halb" }]])),
  );
  const events: ChatStreamEvent[] = [];
  await streamChatMessage("c1", "Hi", (event) => events.push(event));
  expect(events.at(-1)).toEqual({ type: "error", detail: STREAM_INTERRUPTED });
});

test("throws ApiError on 409", async () => {
  server.use(
    http.post("*/api/v1/conversations/c1/messages", () =>
      HttpResponse.json({ detail: "In diesem Chat läuft bereits eine Anfrage" }, { status: 409 }),
    ),
  );
  await expect(streamChatMessage("c1", "Hi", () => undefined)).rejects.toEqual(
    new ApiError(409, "In diesem Chat läuft bereits eine Anfrage"),
  );
});

test("applyChatEvent builds the running answer", () => {
  let turn = startTurn("Hallo");
  turn = applyChatEvent(turn, { type: "tool_start", name: "search", id: "a" });
  turn = applyChatEvent(turn, { type: "tool_end", name: "search", id: "a", isError: true });
  turn = applyChatEvent(turn, { type: "text", delta: "Ok" });
  expect(turn).toEqual({
    userText: "Hallo",
    text: "Ok",
    tools: [{ id: "a", name: "search", state: "error" }],
    error: null,
    finished: false,
  });
  expect(applyChatEvent(turn, { type: "error", detail: "kaputt" })).toMatchObject({ finished: true, error: "kaputt" });
  expect(applyChatEvent(turn, { type: "done", messageId: null }).finished).toBe(true);
});

test("toDisplayMessages hides time prefix, tool_result and thinking", () => {
  const messages = [
    makeMessage({
      id: "u1",
      role: "user",
      content: [
        { type: "text", text: "[Jetzt: Fr, 09.10.2026 20:11 Europe/Berlin]" },
        { type: "text", text: "Was steht an?" },
      ],
    }),
    makeMessage({
      id: "a1",
      role: "assistant",
      content: [
        { type: "thinking", thinking: "", signature: "x" },
        { type: "tool_use", id: "t1", name: "get_agenda", input: {} },
      ],
    }),
    makeMessage({ id: "u2", role: "user", content: [{ type: "tool_result", tool_use_id: "t1", content: "{}" }] }),
    makeMessage({ id: "a2", role: "assistant", content: [{ type: "text", text: "Heute nichts." }] }),
  ];
  expect(toDisplayMessages(messages)).toEqual([
    { id: "u1", role: "user", text: "Was steht an?", tools: [] },
    { id: "a1", role: "assistant", text: "", tools: ["get_agenda"] },
    { id: "a2", role: "assistant", text: "Heute nichts.", tools: [] },
  ]);
});

test("reports interruption on a truncated event at stream end", async () => {
  server.use(
    http.post("*/api/v1/conversations/c1/messages", () => {
      return sseResponse([["text", { delta: "Halb" }]], 'event: done\ndata: {"message_id":"m');
    }),
  );
  const events: ChatStreamEvent[] = [];
  await streamChatMessage("c1", "Hi", (event) => events.push(event));
  expect(events).toEqual([
    { type: "text", delta: "Halb" },
    { type: "error", detail: STREAM_INTERRUPTED },
  ]);
});

test("does not throw when reader.read() rejects (promise resolves)", async () => {
  server.use(
    http.post("*/api/v1/conversations/c1/messages", () => {
      const encoder = new TextEncoder();
      return new HttpResponse(
        new ReadableStream({
          start(controller) {
            controller.enqueue(encoder.encode('event: text\ndata: {"delta":"Halb"}\n\n'));
            // fail on the next read()
            Promise.resolve().then(() => controller.error(new Error("reset")));
          },
        }),
        { headers: { "Content-Type": "text/event-stream" } },
      );
    }),
  );
  const events: ChatStreamEvent[] = [];
  // should resolve, catch handles it
  await streamChatMessage("c1", "Hi", (event) => events.push(event));
  // at least STREAM_INTERRUPTED
  expect(events.some((e) => e.type === "error" && e.detail === STREAM_INTERRUPTED)).toBe(true);
});
