import { screen, waitFor } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import type { Message } from "../lib/types";
import { makeMessage } from "../test/factories";
import { renderRoute } from "../test/render";
import { server } from "../test/server";
import { sseResponse } from "../test/sse";

const conversation = { id: "c1", title: "Planung", created_at: "2026-10-09T18:00:00Z", updated_at: "2026-10-09T18:00:00Z" };
let stored: Message[];

beforeEach(() => {
  stored = [];
  server.use(
    http.get("*/api/v1/conversations", () => HttpResponse.json([conversation])),
    http.get("*/api/v1/conversations/c1/messages", () => HttpResponse.json(stored)),
  );
});

test("shows history without time prefix, with tool hints", async () => {
  stored = [
    makeMessage({
      role: "user",
      content: [
        { type: "text", text: "[Jetzt: Fr, 09.10.2026 20:11 Europe/Berlin]" },
        { type: "text", text: "Was steht an?" },
      ],
    }),
    makeMessage({ role: "assistant", content: [{ type: "tool_use", id: "t1", name: "get_agenda", input: {} }] }),
    makeMessage({ role: "user", content: [{ type: "tool_result", tool_use_id: "t1", content: "{}" }] }),
    makeMessage({ role: "assistant", content: [{ type: "text", text: "Heute **nichts**." }] }),
  ];
  renderRoute("/chat/c1");
  expect(await screen.findByText("Was steht an?")).toBeInTheDocument();
  expect(screen.queryByText(/\[Jetzt:/)).not.toBeInTheDocument();
  expect(screen.getByText(/get_agenda/)).toBeInTheDocument();
  expect(screen.getByText("nichts").tagName).toBe("STRONG");
});

test("sends a message, then shows the stored history", async () => {
  let posted: unknown;
  server.use(
    http.post("*/api/v1/conversations/c1/messages", async ({ request }) => {
      posted = await request.json();
      stored = [
        makeMessage({ role: "user", content: [{ type: "text", text: "[Jetzt: x]" }, { type: "text", text: "Milch kaufen" }] }),
        makeMessage({ role: "assistant", content: [{ type: "text", text: "✓ ToDo „Milch kaufen“ angelegt" }] }),
      ];
      return sseResponse([
        ["tool_start", { name: "create_item", id: "t1" }],
        ["tool_end", { name: "create_item", id: "t1", is_error: false }],
        ["text", { delta: "✓ ToDo angelegt" }],
        ["done", { message_id: "m2", usage: {} }],
      ]);
    }),
  );
  const { user } = renderRoute("/chat/c1");
  const input = await screen.findByLabelText("Nachricht");
  await user.type(input, "Milch kaufen{Enter}");
  expect(await screen.findByText("✓ ToDo „Milch kaufen“ angelegt")).toBeInTheDocument();
  expect(screen.queryByText("✓ ToDo angelegt")).not.toBeInTheDocument();
  await waitFor(() => expect(document.activeElement).toBe(screen.getByLabelText("Nachricht")));
  expect(posted).toEqual({ text: "Milch kaufen" });
  expect(input).toHaveValue("");
});

test("locks input while answering and for empty text", async () => {
  let release!: () => void;
  const gate = new Promise<void>((resolve) => (release = resolve));
  server.use(
    http.post("*/api/v1/conversations/c1/messages", async () => {
      await gate;
      return sseResponse([["text", { delta: "Fertig" }], ["done", { message_id: null, usage: {} }]]);
    }),
  );
  const { user } = renderRoute("/chat/c1");
  const input = await screen.findByLabelText("Nachricht");
  await user.type(input, "   ");
  expect(screen.getByRole("button", { name: "Senden" })).toBeDisabled();
  await user.clear(input);
  await user.type(input, "Hallo{Enter}");
  await waitFor(() => expect(input).toBeDisabled());
  expect(screen.getByRole("button", { name: "Senden" })).toBeDisabled();
  release();
  await waitFor(() => expect(input).not.toBeDisabled());
});

test("shows error events and 409 readably", async () => {
  server.use(
    http.post("*/api/v1/conversations/c1/messages", () =>
      sseResponse([["error", { detail: "Keine Verbindung zur Claude-API." }]]),
    ),
  );
  const { user } = renderRoute("/chat/c1");
  await user.type(await screen.findByLabelText("Nachricht"), "Hi{Enter}");
  expect(await screen.findByRole("alert")).toHaveTextContent("Keine Verbindung zur Claude-API.");

  server.use(
    http.post("*/api/v1/conversations/c1/messages", () =>
      HttpResponse.json({ detail: "In diesem Chat läuft bereits eine Anfrage" }, { status: 409 }),
    ),
  );
  await user.type(screen.getByLabelText("Nachricht"), "Nochmal{Enter}");
  expect(await screen.findByText("In diesem Chat läuft bereits eine Anfrage")).toBeInTheDocument();
  expect(screen.getByLabelText("Nachricht")).toHaveValue("Nochmal");
});

test("new chat creates and opens one", async () => {
  server.use(
    http.post("*/api/v1/conversations", () =>
      HttpResponse.json({ ...conversation, id: "c2", title: null }, { status: 201 }),
    ),
    http.get("*/api/v1/conversations/c2/messages", () => HttpResponse.json([])),
  );
  const { user, router } = renderRoute("/chat");
  await screen.findByText("Planung");
  await user.click(screen.getByRole("button", { name: "Neuer Chat" }));
  await waitFor(() => expect(router.state.location.pathname).toBe("/chat/c2"));
});
