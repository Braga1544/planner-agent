import { screen, waitFor, within } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { makeItem, makeProject } from "../test/factories";
import { renderRoute } from "../test/render";
import { server } from "../test/server";

const project = makeProject({ id: "p1", name: "Gartenhaus", area: "hobby" });

beforeEach(() => {
  server.use(
    http.get("*/api/v1/projects", ({ request }) =>
      HttpResponse.json(new URL(request.url).searchParams.get("area") === "hobby" ? [project] : []),
    ),
    http.get("*/api/v1/items", ({ request }) => {
      const params = new URL(request.url).searchParams;
      expect(params.get("area")).toBe("hobby");
      expect(params.get("status")).toBe("open");
      return HttpResponse.json([
        makeItem({ area: "hobby", title: "Holz bestellen", type: "todo" }),
        makeItem({ area: "hobby", title: "Hochbeet-Idee", type: "idea" }),
        makeItem({ area: "hobby", title: "Im Projekt", project_id: "p1" }),
      ]);
    }),
  );
});

test("shows projects, all open todos and loose ideas/notes of the area", async () => {
  renderRoute("/bereiche/hobby");
  const projects = screen.getByRole("region", { name: "Projekte" });
  expect(await within(projects).findByRole("link", { name: "Gartenhaus" })).toHaveAttribute("href", "/projekte/p1");

  const todos = screen.getByRole("region", { name: "Offene ToDos" });
  expect(await within(todos).findByText("Holz bestellen")).toBeInTheDocument();
  expect(within(todos).getByText("Im Projekt")).toBeInTheDocument();
  expect(within(todos).getByRole("link", { name: "Gartenhaus" })).toHaveAttribute("href", "/projekte/p1");

  const loose = screen.getByRole("region", { name: "Lose Einträge" });
  expect(within(loose).getByText("Hochbeet-Idee")).toBeInTheDocument();
  expect(within(loose).queryByText("Holz bestellen")).not.toBeInTheDocument();
  expect(within(loose).queryByText("Im Projekt")).not.toBeInTheDocument();
});

test("creates a project and opens it", async () => {
  let posted: unknown;
  server.use(
    http.post("*/api/v1/projects", async ({ request }) => {
      posted = await request.json();
      return HttpResponse.json(makeProject({ id: "p2", name: "Fotobuch", area: "hobby" }), { status: 201 });
    }),
    http.get("*/api/v1/projects/p2", () =>
      HttpResponse.json({ ...makeProject({ id: "p2", name: "Fotobuch", area: "hobby" }), open_items: [] }),
    ),
  );
  const { user, router } = renderRoute("/bereiche/hobby");
  await user.type(await screen.findByLabelText("Neues Projekt"), "Fotobuch");
  await user.click(screen.getByRole("button", { name: "Anlegen" }));
  await waitFor(() => expect(router.state.location.pathname).toBe("/projekte/p2"));
  expect(posted).toEqual({ area: "hobby", name: "Fotobuch" });
});

test("new loose entry as idea without due date", async () => {
  let posted: unknown;
  server.use(
    http.post("*/api/v1/items", async ({ request }) => {
      posted = await request.json();
      return HttpResponse.json(makeItem(), { status: 201 });
    }),
  );
  const { user } = renderRoute("/bereiche/hobby");
  await screen.findByText("Holz bestellen");
  await user.click(screen.getByRole("button", { name: "Neuer Eintrag" }));
  const dialog = screen.getByRole("dialog", { name: "Neuer Eintrag" });
  await user.selectOptions(within(dialog).getByLabelText("Typ"), "idea");
  expect(within(dialog).queryByLabelText("Fällig am")).not.toBeInTheDocument();
  await user.type(within(dialog).getByLabelText("Titel"), "Hochbeet");
  await user.click(within(dialog).getByRole("button", { name: "Speichern" }));
  await waitFor(() =>
    expect(posted).toEqual({
      type: "idea",
      area: "hobby",
      project_id: null,
      title: "Hochbeet",
      body: null,
      priority: "normal",
      due_date: null,
    }),
  );
});

test("unknown area", () => {
  renderRoute("/bereiche/nope");
  expect(screen.getByText("Unbekannter Bereich.")).toBeInTheDocument();
});
