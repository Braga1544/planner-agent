import { screen, waitFor, within } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { addDays, formatLongDay, todayBerlin, zonedToIso } from "../lib/time";
import type { Agenda } from "../lib/types";
import { makeItem, makeOccurrence } from "../test/factories";
import { renderRoute } from "../test/render";
import { server } from "../test/server";

const today = todayBerlin();
const dueItem = makeItem({ title: "Steuer abgeben", due_date: today });

function agenda(overrides: Partial<Agenda> = {}): Agenda {
  return {
    start: today,
    end: today,
    events: [
      makeOccurrence({
        title: "Zahnarzt",
        occurrence_start: zonedToIso(today, "14:00"),
        occurrence_end: zonedToIso(today, "15:00"),
      }),
    ],
    due_todos: [dueItem],
    overdue_todos: [makeItem({ title: "Rechnung zahlen", due_date: addDays(today, -2) })],
    ...overrides,
  };
}

const tomorrow = addDays(today, 1);
const empty = (): Agenda => ({ start: tomorrow, end: tomorrow, events: [], due_todos: [], overdue_todos: [] });

function agendaHandler(upcoming: Agenda = empty(), onUpcoming?: (params: URLSearchParams) => void) {
  return http.get("*/api/v1/agenda", ({ request }) => {
    const params = new URL(request.url).searchParams;
    if (params.has("from")) {
      onUpcoming?.(params);
      return HttpResponse.json(upcoming);
    }
    return HttpResponse.json(agenda());
  });
}

test("shows events, overdue and due todos", async () => {
  let requestedDate: string | null = null;
  server.use(
    http.get("*/api/v1/agenda", ({ request }) => {
      const params = new URL(request.url).searchParams;
      if (params.has("from")) return HttpResponse.json(empty());
      requestedDate = params.get("date");
      return HttpResponse.json(agenda());
    }),
  );
  renderRoute("/");
  expect(await screen.findByText("Zahnarzt")).toBeInTheDocument();
  expect(screen.getByText("14:00–15:00")).toBeInTheDocument();
  expect(within(screen.getByRole("region", { name: "Überfällig" })).getByText("Rechnung zahlen")).toBeInTheDocument();
  expect(within(screen.getByRole("region", { name: "Heute fällig" })).getByText("Steuer abgeben")).toBeInTheDocument();
  expect(requestedDate).toBe(today);
});

test("checkbox completes a todo", async () => {
  let patched: unknown;
  server.use(
    agendaHandler(),
    http.patch("*/api/v1/items/:id", async ({ request, params }) => {
      patched = { id: params.id, body: await request.json() };
      return HttpResponse.json({ ...dueItem, status: "done" });
    }),
  );
  const { user } = renderRoute("/");
  await user.click(await screen.findByRole("checkbox", { name: "Steuer abgeben erledigt" }));
  await waitFor(() => expect(patched).toEqual({ id: dueItem.id, body: { status: "done" } }));
});

test("quick add creates a todo", async () => {
  let posted: unknown;
  server.use(
    http.get("*/api/v1/agenda", ({ request }) =>
      HttpResponse.json(
        new URL(request.url).searchParams.has("from") ? empty() : agenda({ events: [], due_todos: [], overdue_todos: [] }),
      ),
    ),
    http.post("*/api/v1/items", async ({ request }) => {
      posted = await request.json();
      return HttpResponse.json(makeItem({ title: "Milch kaufen" }), { status: 201 });
    }),
  );
  const { user } = renderRoute("/");
  await screen.findByText("Keine Termine.");
  await user.type(screen.getByLabelText("Neues ToDo"), "Milch kaufen");
  await user.selectOptions(screen.getByLabelText("Bereich"), "hobby");
  await user.click(screen.getByRole("button", { name: "Hinzufügen" }));
  await waitFor(() =>
    expect(posted).toEqual({ type: "todo", area: "hobby", title: "Milch kaufen", due_date: today }),
  );
  await waitFor(() => expect(screen.getByLabelText("Neues ToDo")).toHaveValue(""));
});

test("shows api errors", async () => {
  server.use(http.get("*/api/v1/agenda", () => HttpResponse.json({ detail: "kaputt" }, { status: 500 })));
  renderRoute("/");
  expect(await screen.findByRole("alert")).toHaveTextContent("kaputt");
});

test("shows upcoming days grouped", async () => {
  const later = addDays(today, 3);
  let params: URLSearchParams | undefined;
  server.use(
    agendaHandler(
      {
        ...empty(),
        events: [
          makeOccurrence({
            title: "Workshop",
            occurrence_start: zonedToIso(later, "10:00"),
            occurrence_end: zonedToIso(later, "11:00"),
          }),
        ],
        due_todos: [makeItem({ title: "Paket abholen", due_date: tomorrow })],
        overdue_todos: [makeItem({ title: "Sollte fehlen", due_date: addDays(today, -5) })],
      },
      (p) => (params = p),
    ),
  );
  renderRoute("/");
  const morgen = await screen.findByRole("region", { name: "Morgen" });
  expect(within(morgen).getByText("Paket abholen")).toBeInTheDocument();
  expect(within(screen.getByRole("region", { name: formatLongDay(later) })).getByText("Workshop")).toBeInTheDocument();
  expect(screen.queryByRole("region", { name: formatLongDay(addDays(today, 2)) })).not.toBeInTheDocument();
  expect(screen.queryByText("Sollte fehlen")).not.toBeInTheDocument();
  expect(params?.get("from")).toBe(tomorrow);
  expect(params?.get("to")).toBe(addDays(tomorrow, 13));
});

test("tomorrow shows nothing planned when empty", async () => {
  server.use(agendaHandler());
  renderRoute("/");
  const morgen = await screen.findByRole("region", { name: "Morgen" });
  expect(within(morgen).getByText("Nichts geplant.")).toBeInTheDocument();
});

test("next 7 days extends the range", async () => {
  const tos: (string | null)[] = [];
  server.use(agendaHandler(empty(), (p) => tos.push(p.get("to"))));
  const { user } = renderRoute("/");
  await screen.findByRole("region", { name: "Morgen" });
  await user.click(screen.getByRole("button", { name: "Weitere 7 Tage" }));
  await waitFor(() => expect(tos).toContain(addDays(tomorrow, 20)));
});
