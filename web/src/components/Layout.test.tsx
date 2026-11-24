import { screen } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { renderRoute } from "../test/render";
import { server } from "../test/server";

beforeEach(() =>
  server.use(
    http.get("*/api/v1/me", () => HttpResponse.json({ token_name: "Web" })),
    http.get("*/api/v1/calendar-sources", () => HttpResponse.json([])),
  ),
);

test("nav has main pages and areas", async () => {
  renderRoute("/einstellungen");
  await screen.findByText("Verbunden als Web");
  for (const name of ["Heute", "Chat", "Kalender", "Einstellungen", "Arbeit", "Business", "Hobby", "Privat"]) {
    expect(screen.getAllByRole("link", { name: new RegExp(name) }).length).toBeGreaterThan(0);
  }
});

test("search navigates to /suche?q=", async () => {
  const { user, router } = renderRoute("/einstellungen");
  await user.type(screen.getByRole("searchbox", { name: "Suche" }), "Fotobuch{Enter}");
  expect(router.state.location.pathname).toBe("/suche");
  expect(new URLSearchParams(router.state.location.search).get("q")).toBe("Fotobuch");
});
