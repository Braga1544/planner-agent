import { CircleAlert } from "lucide-react";

export function ErrorBanner({ error }: { error: unknown }) {
  const message = error instanceof Error ? error.message : "Unbekannter Fehler";
  return (
    <div role="alert" className="flex items-start gap-2.5 rounded-lg border border-danger/30 bg-danger/5 px-3 py-2.5 text-sm text-danger">
      <CircleAlert aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
      <span className="min-w-0 break-words">{message}</span>
    </div>
  );
}
