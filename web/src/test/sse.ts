import { HttpResponse } from "msw";

export function sseResponse(events: Array<[string, unknown]>, extra = ""): Response {
  const body = events.map(([event, data]) => `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`).join("") + extra;
  return new HttpResponse(body, { headers: { "Content-Type": "text/event-stream" } });
}
