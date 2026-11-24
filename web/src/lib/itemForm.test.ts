import { makeItem } from "../test/factories";
import { emptyItemForm, formToItemCreate, formToItemUpdate, groupByType, itemToForm } from "./itemForm";

test("create payload trims and nulls empty fields", () => {
  const values = { ...emptyItemForm({ area: "hobby", projectId: "p1" }), title: "  Material bestellen ", body: "  ", dueDate: "2026-10-16" };
  expect(formToItemCreate(values)).toEqual({
    type: "todo",
    area: "hobby",
    project_id: "p1",
    title: "Material bestellen",
    body: null,
    priority: "normal",
    due_date: "2026-10-16",
  });
});

test("ideas and notes have no due date", () => {
  const values = { ...emptyItemForm(), type: "idea" as const, title: "Hochbeet", dueDate: "2026-10-16" };
  expect(formToItemCreate(values).due_date).toBeNull();
});

test("update payload includes status; itemToForm is the inverse", () => {
  const item = makeItem({ title: "A", body: "Text", project_id: null, status: "done", due_date: "2026-10-20", priority: "high" });
  const values = itemToForm(item);
  expect(values).toMatchObject({ title: "A", body: "Text", projectId: "", status: "done", dueDate: "2026-10-20", priority: "high" });
  expect(formToItemUpdate(values)).toMatchObject({ status: "done", project_id: null, due_date: "2026-10-20" });
});

test("groupByType", () => {
  const groups = groupByType([makeItem({ type: "idea", title: "I" }), makeItem({ type: "todo", title: "T" })]);
  expect(groups.todo.map((i) => i.title)).toEqual(["T"]);
  expect(groups.idea.map((i) => i.title)).toEqual(["I"]);
  expect(groups.note).toEqual([]);
});
