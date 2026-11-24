import { http, HttpResponse } from "msw";
import { server } from "../test/server";
import { api, ApiError, apiFetch, errorMessage, onUnauthorized } from "./api";
import { getToken, setToken } from "./token";

test("sends the bearer token and returns json", async () => {
  setToken("geheim");
  server.use(
    http.get("*/api/v1/me", ({ request }) =>
      HttpResponse.json({ token_name: request.headers.get("Authorization") }),
    ),
  );
  expect(await api.get<{ token_name: string }>("/me")).toEqual({ token_name: "Bearer geheim" });
});

test("sends a json body with content-type", async () => {
  let received: unknown;
  let contentType: string | null = null;
  server.use(
    http.post("*/api/v1/items", async ({ request }) => {
      received = await request.json();
      contentType = request.headers.get("Content-Type");
      return HttpResponse.json({ id: "1" }, { status: 201 });
    }),
  );
  await api.post("/items", { title: "A" });
  expect(received).toEqual({ title: "A" });
  expect(contentType).toBe("application/json");
});

test("returns undefined on 204", async () => {
  server.use(http.delete("*/api/v1/events/1", () => new HttpResponse(null, { status: 204 })));
  expect(await api.delete("/events/1")).toBeUndefined();
});

test("throws ApiError with the detail text", async () => {
  server.use(
    http.get("*/api/v1/items", () => HttpResponse.json({ detail: "Projekt nicht gefunden" }, { status: 404 })),
  );
  await expect(api.get("/items")).rejects.toEqual(new ApiError(404, "Projekt nicht gefunden"));
});

test("joins fastapi validation errors", () => {
  const body = { detail: [{ msg: "Field required" }, { msg: "Input should be a valid date" }] };
  expect(errorMessage(body, 422)).toBe("Field required; Input should be a valid date");
  expect(errorMessage(null, 500)).toBe("Fehler 500");
  expect(errorMessage({ detail: [] }, 422)).toBe("Fehler 422");
});

test("401 clears the token and notifies listeners", async () => {
  setToken("alt");
  const listener = vi.fn();
  const off = onUnauthorized(listener);
  server.use(http.get("*/api/v1/me", () => HttpResponse.json({ detail: "Nicht authentifiziert" }, { status: 401 })));
  await expect(api.get("/me")).rejects.toBeInstanceOf(ApiError);
  expect(getToken()).toBeNull();
  expect(listener).toHaveBeenCalledTimes(1);
  off();
});

test("network error maps to 'server unreachable'", async () => {
  server.use(http.get("*/api/v1/me", () => HttpResponse.error()));
  await expect(apiFetch("/me")).rejects.toEqual(new ApiError(0, "Server nicht erreichbar"));
});
