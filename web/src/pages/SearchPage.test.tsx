import { screen } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { makeEvent, makeItem, makeProject } from "../test/factories";
import { renderRoute } from "../test/render";
import { server } from "../test/server";

test("shows grouped hits with links", async () => {
  let query: string | null = null;
  server.use(
    http.get("*/api/v1/search", ({ request }) => {
      query = new URL(request.url).searchParams.get("q");
      return HttpResponse.json({
        items: [makeItem({ title: "Fotobuch Layout" })],
        projects: [makeProject({ id: "p1", name: "Fotobuch" })],
        events: [makeEvent({ title: "Fotobuch Review", start_at: "2026-10-13T16:00:00Z", end_at: null })],
      });
    }),
  );
  renderRoute("/suche?q=Fotobuch");
  expect(await screen.findByText("Fotobuch Layout")).toBeInTheDocument();
  expect(screen.getByRole("link", { name: "Fotobuch" })).toHaveAttribute("href", "/projekte/p1");
  expect(screen.getByRole("link", { name: "Fotobuch Review" })).toHaveAttribute("href", "/kalender?woche=2026-10-12");
  expect(screen.getByText(/18:00/)).toBeInTheDocument();
  expect(query).toBe("Fotobuch");
});

test("reports no hits", async () => {
  server.use(http.get("*/api/v1/search", () => HttpResponse.json({ items: [], projects: [], events: [] })));
  renderRoute("/suche?q=xyz");
  expect(await screen.findByText("Keine Treffer für „xyz“.")).toBeInTheDocument();
});

test("no query, no request", () => {
  renderRoute("/suche");
  expect(screen.getByText("Gib oben einen Suchbegriff ein.")).toBeInTheDocument();
});
