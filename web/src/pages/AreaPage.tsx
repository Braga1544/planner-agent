import { ChevronRight, Folder, Plus } from "lucide-react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useState, type FormEvent } from "react";
import { Link, NavLink, useNavigate, useParams } from "react-router";
import { ErrorBanner } from "../components/ErrorBanner";
import { ItemDialog } from "../components/ItemDialog";
import { ItemRow } from "../components/ItemRow";
import { buttonClass, cardClass, inputClass, PageHeader, Section, SectionHeader, secondaryButtonClass } from "../components/ui";
import { api } from "../lib/api";
import { groupByType } from "../lib/itemForm";
import { ITEM_GROUP_LABELS, PROJECT_STATUS_LABELS } from "../lib/labels";
import { useInvalidateAll } from "../lib/mutations";
import { keys } from "../lib/queryKeys";
import { AREAS, type Item, type ItemType, type Project } from "../lib/types";

export function AreaPage() {
  const { area } = useParams();
  const known = AREAS.find((candidate) => candidate.slug === area);
  const navigate = useNavigate();
  const invalidate = useInvalidateAll();
  const projects = useQuery({
    queryKey: keys.projects(area),
    queryFn: () => api.get<Project[]>(`/projects?area=${area}`),
    enabled: Boolean(known),
  });
  const items = useQuery({
    queryKey: keys.items({ area, status: "open" }),
    queryFn: () => api.get<Item[]>(`/items?area=${area}&status=open`),
    enabled: Boolean(known),
  });
  const [newProject, setNewProject] = useState("");
  const [dialog, setDialog] = useState<{ item?: Item } | null>(null);
  const createProject = useMutation({
    mutationFn: (name: string) => api.post<Project>("/projects", { area, name }),
    onSuccess: async (project) => {
      await invalidate();
      navigate(`/projekte/${project.id}`);
    },
  });

  if (!known) return <p className="text-muted">Unbekannter Bereich.</p>;

  function submitProject(event: FormEvent) {
    event.preventDefault();
    const name = newProject.trim();
    if (name) createProject.mutate(name);
  }

  const openItems = items.data ?? [];
  // project todos show up here too, ideas/notes only on the project page
  const todos = openItems.filter((item) => item.type === "todo");
  const looseGroups = groupByType(openItems.filter((item) => item.project_id === null && item.type !== "todo"));
  const projectsById = new Map((projects.data ?? []).map((project) => [project.id, project]));
  const looseTypes: ItemType[] = ["idea", "note"];

  return (
    <div className="space-y-8">
      <div className="space-y-5">
        <nav aria-label="Bereiche" className="-mx-4 flex gap-1.5 overflow-x-auto px-4 md:hidden">
          {AREAS.map((option) => (
            <NavLink
              key={option.slug}
              to={`/bereiche/${option.slug}`}
              className={({ isActive }) =>
                `whitespace-nowrap rounded-full border px-3 py-1 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40 ${
                  isActive ? "border-transparent bg-accent-soft font-medium text-accent" : "border-border bg-surface text-text/80 hover:text-text"
                }`
              }
            >
              {option.name}
            </NavLink>
          ))}
        </nav>
        <PageHeader title={known.name} />
      </div>

      <section aria-label="Projekte" className="space-y-1.5">
        <SectionHeader title="Projekte" />
        {projects.isError && <ErrorBanner error={projects.error} />}
        <div className={`${cardClass} overflow-hidden`}>
          {projects.data && projects.data.length > 0 && (
            <ul className="divide-y divide-border border-b border-border">
              {projects.data.map((project) => (
                <li key={project.id} className="flex items-center gap-3 transition-colors hover:bg-bg">
                  <Link
                    to={`/projekte/${project.id}`}
                    className="flex min-w-0 flex-1 items-center gap-3 py-2.5 pl-4 font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-accent/40"
                  >
                    <Folder aria-hidden="true" className="size-[1.125rem] shrink-0 text-muted" strokeWidth={1.75} />
                    <span className="truncate">{project.name}</span>
                  </Link>
                  {project.status !== "active" && (
                    <span className="rounded-md border border-border px-1.5 text-xs leading-5 text-muted">
                      {PROJECT_STATUS_LABELS[project.status]}
                    </span>
                  )}
                  <ChevronRight aria-hidden="true" className="mr-3 size-4 shrink-0 text-muted" />
                </li>
              ))}
            </ul>
          )}
          <form onSubmit={submitProject} className="flex gap-2 p-2">
            <div className="relative min-w-0 flex-1">
              <Plus aria-hidden="true" className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted" />
              <input
                aria-label="Neues Projekt"
                placeholder="Neues Projekt…"
                value={newProject}
                onChange={(e) => setNewProject(e.target.value)}
                className={`${inputClass} border-transparent pl-9 hover:border-transparent`}
              />
            </div>
            <button type="submit" className={secondaryButtonClass} disabled={createProject.isPending || !newProject.trim()}>
              Anlegen
            </button>
          </form>
        </div>
        {createProject.isError && <ErrorBanner error={createProject.error} />}
      </section>

      {items.isError && <ErrorBanner error={items.error} />}

      <Section title="Offene ToDos" empty="Keine offenen ToDos.">
        {todos.map((item) => {
          const project = item.project_id ? projectsById.get(item.project_id) : undefined;
          return (
            <ItemRow key={item.id} item={item} showArea={false} project={project} onEdit={(selected) => setDialog({ item: selected })} />
          );
        })}
      </Section>

      <section aria-label="Lose Einträge" className="space-y-4">
        <div className="flex items-center justify-between gap-3 border-t border-border pt-6">
          <h2 className="text-base font-semibold tracking-tight">Lose Einträge</h2>
          <button type="button" className={buttonClass} onClick={() => setDialog({})}>
            <Plus aria-hidden="true" />
            Neuer Eintrag
          </button>
        </div>
        {looseTypes.map((type) => (
          <Section key={type} title={ITEM_GROUP_LABELS[type]} empty="Keine.">
            {looseGroups[type].map((item) => (
              <ItemRow key={item.id} item={item} showArea={false} onEdit={(selected) => setDialog({ item: selected })} />
            ))}
          </Section>
        ))}
      </section>

      {dialog && <ItemDialog item={dialog.item} defaults={{ area: known.slug }} onClose={() => setDialog(null)} />}
    </div>
  );
}
