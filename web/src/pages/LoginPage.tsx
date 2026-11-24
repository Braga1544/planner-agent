import { KeyRound } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useAuth } from "../auth";
import { ErrorBanner } from "../components/ErrorBanner";
import { buttonClass, cardClass, Field, inputClass, pageTitleClass } from "../components/ui";
import { api, ApiError } from "../lib/api";
import { clearToken, setToken } from "../lib/token";

export function LoginPage() {
  const { login } = useAuth();
  const [value, setValue] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const token = value.trim();
    if (!token) return;
    setBusy(true);
    setError(null);
    setToken(token); // api.get reads it from there
    try {
      await api.get<{ token_name: string }>("/me");
      login(token);
    } catch (err) {
      clearToken();
      setError(
        err instanceof ApiError && err.status === 401
          ? "Token ungültig oder gesperrt."
          : err instanceof Error
            ? err.message
            : "Unbekannter Fehler",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-h-screen items-start justify-center px-4 pt-[18vh]">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-3">
          <div className="flex size-10 items-center justify-center rounded-xl bg-accent-soft text-accent">
            <KeyRound aria-hidden="true" className="size-5" strokeWidth={1.75} />
          </div>
          <div className="space-y-1.5">
            <p className="text-sm font-medium text-muted">Planungs-Agent</p>
            <h1 className={pageTitleClass}>Verbinden</h1>
          </div>
          <p className="text-sm text-muted">
            Gib einen Geräte-Token ein. Erzeugen kannst du ihn auf dem Server mit{" "}
            <code className="rounded border border-border bg-surface px-1 py-px text-[0.8125rem] text-text">python -m app.cli create-token "Web"</code>.
          </p>
        </div>
        <form onSubmit={submit} className={`${cardClass} space-y-4 p-4`}>
          <Field label="Geräte-Token">
            <input type="password" autoComplete="off" value={value} onChange={(e) => setValue(e.target.value)} className={inputClass} />
          </Field>
          <button type="submit" className={`${buttonClass} w-full`} disabled={busy || !value.trim()}>
            Verbinden
          </button>
        </form>
        {error && <ErrorBanner error={new Error(error)} />}
      </div>
    </div>
  );
}
