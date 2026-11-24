import { fireEvent, screen, waitFor, within } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { makeEvent, makeOccurrence } from "../test/factories";
import { renderRoute } from "../test/render";
import { server } from "../test/server";

const training = makeOccurrence({
  title: "Training",
  is_recurring: true,
  occurrence_start: "2026-10-13T19:00:00+02:00",
  occurrence_end: "2026-10-13T20:30:00+02:00",
});
const daily = makeOccurrence({
  title: "Daily",
  source: "ics_import",
  occurrence_start: "2026-10-12T09:15:00+02:00",
  occurrence_end: "2026-10-12T09:30:00+02:00",
});

let range: { from: string | null; to: string | null };

beforeEach(() => {
  server.use(
    http.get("*/api/v1/events", ({ request }) => {
      const params = new URL(request.url).searchParams;
      range = { from: params.get("from"), to: params.get("to") };
      return HttpResponse.json([training, daily]);
    }),
  );
});

test("shows the week with events on the right day", async () => {
  renderRoute("/kalender?woche=2026-10-12");
  const tuesday = await screen.findByRole("region", { name: "Dienstag, 13. Oktober 2026" });
  expect(await within(tuesday).findByText("Training")).toBeInTheDocument();
  expect(within(screen.getByRole("region", { name: "Montag, 12. Oktober 2026" })).getByText("Daily")).toBeInTheDocument();
  expect(range).toEqual({ from: "2026-10-12T00:00:00+02:00", to: "2026-10-19T00:00:00+02:00" });
});

test("next week jumps seven days", async () => {
  const { user, router } = renderRoute("/kalender?woche=2026-10-12");
  await screen.findByText("Training");
  await user.click(screen.getByRole("button", { name: "Woche →" }));
  expect(new URLSearchParams(router.state.location.search).get("woche")).toBe("2026-10-19");
});

test("creates an event", async () => {
  let posted: unknown;
  server.use(
    http.post("*/api/v1/events", async ({ request }) => {
      posted = await request.json();
      return HttpResponse.json(makeEvent(), { status: 201 });
    }),
  );
  const { user } = renderRoute("/kalender?woche=2026-10-12");
  await screen.findByText("Training");
  await user.click(screen.getByRole("button", { name: "Neuer Termin" }));
  const dialog = screen.getByRole("dialog", { name: "Neuer Termin" });
  await user.type(within(dialog).getByLabelText("Titel"), "Zahnarzt");
  fireEvent.change(within(dialog).getByLabelText("Datum"), { target: { value: "2026-10-12" } });
  fireEvent.change(within(dialog).getByLabelText("Beginn"), { target: { value: "14:00" } });
  fireEvent.change(within(dialog).getByLabelText("Ende"), { target: { value: "15:00" } });
  await user.click(within(dialog).getByRole("button", { name: "Speichern" }));
  await waitFor(() =>
    expect(posted).toMatchObject({
      title: "Zahnarzt",
      start_at: "2026-10-12T14:00:00+02:00",
      end_at: "2026-10-12T15:00:00+02:00",
      all_day: false,
    }),
  );
  await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
});

test("imported events are read-only", async () => {
  server.use(
    http.get(`*/api/v1/events/${daily.event_id}`, () =>
      HttpResponse.json(makeEvent({ id: daily.event_id, title: "Daily", source: "ics_import" })),
    ),
  );
  const { user } = renderRoute("/kalender?woche=2026-10-12");
  await user.click(await screen.findByText("Daily"));
  const dialog = await screen.findByRole("dialog", { name: "Daily" });
  expect(within(dialog).getByText(/nur lesbar/)).toBeInTheDocument();
  expect(within(dialog).queryByRole("button", { name: "Speichern" })).not.toBeInTheDocument();
});

test("deletes an own event after confirm", async () => {
  let deleted = false;
  vi.spyOn(window, "confirm").mockReturnValue(true);
  server.use(
    http.get(`*/api/v1/events/${training.event_id}`, () =>
      HttpResponse.json(
        makeEvent({ id: training.event_id, title: "Training", start_at: "2026-10-06T17:00:00Z", end_at: "2026-10-06T18:30:00Z", rrule: "FREQ=WEEKLY" }),
      ),
    ),
    http.delete(`*/api/v1/events/${training.event_id}`, () => {
      deleted = true;
      return new HttpResponse(null, { status: 204 });
    }),
  );
  const { user } = renderRoute("/kalender?woche=2026-10-12");
  await user.click(await screen.findByText("Training"));
  const dialog = await screen.findByRole("dialog", { name: "Termin bearbeiten" });
  expect(within(dialog).getByLabelText("Wiederholung")).toHaveValue("WEEKLY");
  expect(within(dialog).getByText("Änderungen gelten für die ganze Serie.")).toBeInTheDocument();
  await user.click(within(dialog).getByRole("button", { name: "Löschen" }));
  expect(window.confirm).toHaveBeenCalledWith("Serie „Training“ mit allen Wiederholungen löschen?");
  await waitFor(() => expect(deleted).toBe(true));
});
