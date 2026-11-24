import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { App } from "./App";
import { getToken, setToken } from "./lib/token";
import { server } from "./test/server";

beforeEach(() => window.history.replaceState({}, "", "/einstellungen"));

test("no token shows the connect page; valid token signs in", async () => {
  server.use(
    http.get("*/api/v1/me", ({ request }) =>
      request.headers.get("Authorization") === "Bearer abc"
        ? HttpResponse.json({ token_name: "Web" })
        : HttpResponse.json({ detail: "Ungültiger oder gesperrter Token" }, { status: 401 }),
    ),
    http.get("*/api/v1/calendar-sources", () => HttpResponse.json([])),
  );
  const user = userEvent.setup();
  render(<App />);
  await user.type(screen.getByLabelText("Geräte-Token"), "abc");
  await user.click(screen.getByRole("button", { name: "Verbinden" }));
  expect(await screen.findByText("Verbunden als Web")).toBeInTheDocument();
  expect(getToken()).toBe("abc");
});

test("wrong token shows an error and is not stored", async () => {
  server.use(http.get("*/api/v1/me", () => HttpResponse.json({ detail: "x" }, { status: 401 })));
  const user = userEvent.setup();
  render(<App />);
  await user.type(screen.getByLabelText("Geräte-Token"), "falsch");
  await user.click(screen.getByRole("button", { name: "Verbinden" }));
  expect(await screen.findByText("Token ungültig oder gesperrt.")).toBeInTheDocument();
  expect(getToken()).toBeNull();
});

test("sign out goes back to the connect page", async () => {
  setToken("abc");
  server.use(
    http.get("*/api/v1/me", () => HttpResponse.json({ token_name: "Web" })),
    http.get("*/api/v1/calendar-sources", () => HttpResponse.json([])),
  );
  const user = userEvent.setup();
  render(<App />);
  await user.click(await screen.findByRole("button", { name: "Abmelden" }));
  expect(screen.getByLabelText("Geräte-Token")).toBeInTheDocument();
  expect(getToken()).toBeNull();
});

test("401 during the session goes to the connect page", async () => {
  setToken("abgelaufen");
  server.use(
    http.get("*/api/v1/me", () => HttpResponse.json({ detail: "x" }, { status: 401 })),
    http.get("*/api/v1/calendar-sources", () => HttpResponse.json({ detail: "x" }, { status: 401 })),
  );
  render(<App />);
  expect(await screen.findByLabelText("Geräte-Token")).toBeInTheDocument();
  expect(getToken()).toBeNull();
});
