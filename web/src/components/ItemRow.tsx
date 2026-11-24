import { CalendarClock, FolderOpen, Lightbulb, StickyNote } from "lucide-react";
import { Link } from "react-router";
import { formatDay, todayBerlin } from "../lib/time";
import { areaName, type Item, type Project } from "../lib/types";
import { useUpdateItem } from "../lib/mutations";

export function ItemRow({
  item,
  onEdit,
  project,
  showArea = true,
}: {
  item: Item;
  onEdit?: (item: Item) => void;
  project?: Pick<Project, "id" | "name">;
  showArea?: boolean;
}) {
  const update = useUpdateItem();
  const done = item.status === "done";
  const overdue = !done && item.due_date !== null && item.due_date < todayBerlin();
  const TypeIcon = item.type === "idea" ? Lightbulb : StickyNote;

  return (
    <li className="flex items-start gap-3 px-4 py-2.5 transition-colors hover:bg-bg">
      <span className="flex h-6 w-[1.125rem] shrink-0 items-center justify-center">
        {item.type === "todo" ? (
          <input
            type="checkbox"
            className="check"
            aria-label={`${item.title} erledigt`}
            checked={done}
            disabled={update.isPending}
            onChange={() => update.mutate({ id: item.id, changes: { status: done ? "open" : "done" } })}
          />
        ) : (
          <TypeIcon aria-hidden="true" className="size-[1.125rem] text-muted" strokeWidth={1.75} />
        )}
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex min-h-6 items-center gap-2">
          <button
            type="button"
            onClick={() => onEdit?.(item)}
            disabled={!onEdit}
            className={`min-w-0 break-words rounded text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40 disabled:cursor-default ${
              done ? "text-muted line-through" : ""
            } ${onEdit ? "hover:text-accent" : ""}`}
          >
            {item.title}
          </button>
          {item.priority === "high" && (
            <span
              role="img"
              aria-label="Hohe Priorität"
              title="Hohe Priorität"
              className="size-1.5 shrink-0 rounded-full bg-danger"
            />
          )}
        </div>
        {(showArea || project || item.due_date) && (
          <div className="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted">
            {showArea && <span>{areaName(item.area)}</span>}
            {project && (
              <Link
                to={`/projekte/${project.id}`}
                className="inline-flex items-center gap-1 rounded hover:text-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
              >
                <FolderOpen aria-hidden="true" className="size-3.5" strokeWidth={1.75} />
                {project.name}
              </Link>
            )}
            {item.due_date && (
              <span className={`inline-flex items-center gap-1 ${overdue ? "text-danger" : ""}`}>
                <CalendarClock aria-hidden="true" className="size-3.5" strokeWidth={1.75} />
                fällig {formatDay(item.due_date)}
              </span>
            )}
          </div>
        )}
        {update.isError && (
          <div role="alert" className="mt-1 text-xs text-danger">
            {update.error.message}
          </div>
        )}
      </div>
    </li>
  );
}
