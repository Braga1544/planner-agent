import { Plus } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useCreateItem } from "../lib/mutations";
import { AREAS, type AreaSlug } from "../lib/types";
import { ErrorBanner } from "./ErrorBanner";
import { buttonClass, cardClass, compactInputClass, inputClass } from "./ui";

export function QuickAddTodo({ defaultDue }: { defaultDue: string }) {
  const create = useCreateItem();
  const [title, setTitle] = useState("");
  const [area, setArea] = useState<AreaSlug>("personal");
  const [due, setDue] = useState(defaultDue);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const text = title.trim();
    if (!text) return;
    try {
      await create.mutateAsync({ type: "todo", area, title: text, due_date: due || null });
      setTitle("");
    } catch {
      // error comes through create.error
    }
  }

  // 2 rows on mobile, one from sm up
  return (
    <form onSubmit={submit} aria-label="Schnellerfassung" className={`${cardClass} flex flex-wrap items-center gap-2 p-2`}>
      <div className="relative order-1 min-w-0 flex-1 basis-48 sm:basis-56">
        <Plus aria-hidden="true" className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted" />
        <input
          aria-label="Neues ToDo"
          placeholder="Neues ToDo…"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          className={`${inputClass} border-transparent pl-9 hover:border-transparent`}
        />
      </div>
      <select
        aria-label="Bereich"
        value={area}
        onChange={(event) => setArea(event.target.value as AreaSlug)}
        className={`${compactInputClass} order-3 min-w-0 grow basis-[calc(50%-0.25rem)] sm:order-2 sm:grow-0 sm:basis-auto`}
      >
        {AREAS.map((option) => (
          <option key={option.slug} value={option.slug}>
            {option.name}
          </option>
        ))}
      </select>
      <input
        type="date"
        aria-label="Fällig am"
        value={due}
        onChange={(event) => setDue(event.target.value)}
        className={`${compactInputClass} order-4 min-w-0 grow basis-[calc(50%-0.25rem)] sm:order-3 sm:grow-0 sm:basis-auto`}
      />
      <button type="submit" className={`${buttonClass} order-2 sm:order-4`} disabled={create.isPending || !title.trim()}>
        Hinzufügen
      </button>
      {create.isError && (
        <div className="order-5 w-full">
          <ErrorBanner error={create.error} />
        </div>
      )}
    </form>
  );
}
