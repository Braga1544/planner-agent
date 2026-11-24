import { screen, waitFor } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { makeSource } from "../test/factories";
import { renderRoute } from "../test/render";
import { server } from "../test/server";

const teams = makeSource({ id: "s1", name: "Teams", last_error: "ConnectError: offline" });

beforeEach(() => {
  server.use(
    http.get("*/api/v1/me", () => HttpResponse.json({ token_name: "Web" })),
    http.get("*/api/v1/calendar-sources", () => HttpResponse.json([teams])),
  );
});

test("lists sources with last error and creates new ones", async () => {
  let posted: unknown;
  server.use(
    http.post("*/api/v1/calendar-sources", async ({ request }) => {
      posted = await request.json();
      return HttpResponse.json(makeSource({ name: "iCloud" }), { status: 201 });
    }),
  );
  const { user } = renderRoute("/einstellungen");
  expect(await screen.findByText("ConnectError: offline")).toBeInTheDocument();
  await user.type(screen.getByLabelText("Name"), "iCloud");
  await user.type(screen.getByLabelText("ICS-URL"), "webcal://p01.icloud.com/x.ics");
  await user.selectOptions(screen.getByLabelText("Bereich"), "personal");
  await user.click(screen.getByRole("button", { name: "Hinzufügen" }));
  await waitFor(() =>
    expect(posted).toEqual({ name: "iCloud", url: "webcal://p01.icloud.com/x.ics", area: "personal" }),
  );
});

test("syncs, toggles and deletes a source", async () => {
  let patched: unknown;
  let deleted = false;
  vi.spyOn(window, "confirm").mockReturnValue(true);
  server.use(
    http.post("*/api/v1/calendar-sources/s1/sync", () =>
      HttpResponse.json({ created: 5, updated: 0, deleted: 0, error: null }),
    ),
    http.patch("*/api/v1/calendar-sources/s1", async ({ request }) => {
      patched = await request.json();
      return HttpResponse.json({ ...teams, enabled: false });
    }),
    http.delete("*/api/v1/calendar-sources/s1", () => {
      deleted = true;
      return new HttpResponse(null, { status: 204 });
    }),
  );
  const { user } = renderRoute("/einstellungen");
  await user.click(await screen.findByRole("button", { name: "Teams synchronisieren" }));
  expect(await screen.findByText("5 neu, 0 geändert, 0 entfernt")).toBeInTheDocument();
  await user.click(screen.getByRole("checkbox", { name: "Teams aktiv" }));
  await waitFor(() => expect(patched).toEqual({ enabled: false }));
  await user.click(screen.getByRole("button", { name: "Teams löschen" }));
  await waitFor(() => expect(deleted).toBe(true));
});

test("shows a sync error in red", async () => {
  server.use(
    http.post("*/api/v1/calendar-sources/s1/sync", () =>
      HttpResponse.json({ created: 0, updated: 0, deleted: 0, error: "ConnectError: offline" }),
    ),
  );
  const { user } = renderRoute("/einstellungen");
  await user.click(await screen.findByRole("button", { name: "Teams synchronisieren" }));
  const messages = await screen.findAllByText("ConnectError: offline");
  expect(messages.some((el) => el.className.includes("text-danger"))).toBe(true);
});
