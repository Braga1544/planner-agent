import { parseSseChunk, readSse, type SseEvent } from "./sse";

function streamOf(...parts: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  return new ReadableStream({
    start(controller) {
      parts.forEach((part) => controller.enqueue(encoder.encode(part)));
      controller.close();
    },
  });
}

async function collect(stream: ReadableStream<Uint8Array>): Promise<SseEvent[]> {
  const events: SseEvent[] = [];
  for await (const event of readSse(stream)) events.push(event);
  return events;
}

test("parses events across chunk boundaries and skips comments", async () => {
  const events = await collect(
    streamOf('event: te', 'xt\ndata: {"delta":"Hal"}\n\n: ping\n\n', 'event: text\r\ndata: {"delta":"lo"}\r\n\r\n'),
  );
  expect(events).toEqual([
    { event: "text", data: { delta: "Hal" } },
    { event: "text", data: { delta: "lo" } },
  ]);
});

test("reads a last event without trailing blank line", async () => {
  expect(await collect(streamOf('event: done\ndata: {"message_id":"m1"}'))).toEqual([
    { event: "done", data: { message_id: "m1" } },
  ]);
});

test("parseSseChunk: default event name, non-json data, comment only", () => {
  expect(parseSseChunk("data: hallo")).toEqual({ event: "message", data: "hallo" });
  expect(parseSseChunk(": ping")).toBeNull();
});

test("ignores a truncated final event without valid json", async () => {
  const events = await collect(streamOf('event: done\ndata: {"message_id":"m'));
  expect(events).toEqual([]);
});
