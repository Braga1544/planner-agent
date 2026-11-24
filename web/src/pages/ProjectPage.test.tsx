import { screen, waitFor, within } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { makeItem, makeProject } from "../test/factories";
import { renderRoute } from "../test/render";
import { server } from "../test/server";

const project = makeProject({ id: "p1", name: "Gartenhaus", area: "hobby", description: "## Ziel\nMehr Stauraum" });
const item = makeItem({ area: "hobby", project_id: "p1", title: "Material bestellen" });

beforeEach(() => {
  server.use(
    http.get("*/api/v1/projects/p1", () => HttpResponse.json({ ...project, open_items: [item] })),
    http.get("*/api/v1/projects", () => HttpResponse.json([project])),
  );
});

test("shows project info as markdown and open entries", async () => {
  renderRoute("/projekte/p1");
  expect(await screen.findByRole("heading", { name: "Ziel" })).toBeInTheDocument();
  expect(screen.getByText("Material bestellen")).toBeInTheDocument();
});

test("edits project info and status", async () => {
  const patches: unknown[] = [];
  server.use(
    http.patch("*/api/v1/projects/p1", async ({ request }) => {
      patches.push(await request.json());
      return HttpResponse.json(project);
    }),
  );
  const { user } = renderRoute("/projekte/p1");
  await user.click(await screen.findByRole("button", { name: "Bearbeiten" }));
  const editor = screen.getByLabelText("Projektinfos bearbeiten");
  await user.clear(editor);
  await user.type(editor, "Neu");
  await user.click(screen.getByRole("button", { name: "Speichern" }));
  await user.selectOptions(screen.getByLabelText("Status"), "paused");
  await waitFor(() => expect(patches).toEqual([{ description: "Neu" }, { status: "paused" }]));
});

test("new entry in project and archiving", async () => {
  let posted: unknown;
  let archivedId: unknown;
  vi.spyOn(window, "confirm").mockReturnValue(true);
  server.use(
    http.post("*/api/v1/items", async ({ request }) => {
      posted = await request.json();
      return HttpResponse.json(makeItem(), { status: 201 });
    }),
    http.delete("*/api/v1/items/:id", ({ params }) => {
      archivedId = params.id;
      return HttpResponse.json({ ...item, status: "archived" });
    }),
  );
  const { user } = renderRoute("/projekte/p1");
  await user.click(await screen.findByRole("button", { name: "Neuer Eintrag" }));
  let dialog = screen.getByRole("dialog", { name: "Neuer Eintrag" });
  await user.type(within(dialog).getByLabelText("Titel"), "Fundament gießen");
  await user.click(within(dialog).getByRole("button", { name: "Speichern" }));
  await waitFor(() => expect(posted).toMatchObject({ area: "hobby", project_id: "p1", title: "Fundament gießen", type: "todo" }));

  await user.click(screen.getByRole("button", { name: "Material bestellen" }));
  dialog = screen.getByRole("dialog", { name: "Eintrag bearbeiten" });
  expect(within(dialog).getByLabelText("Titel")).toHaveValue("Material bestellen");
  await user.click(within(dialog).getByRole("button", { name: "Archivieren" }));
  await waitFor(() => expect(archivedId).toBe(item.id));
});
