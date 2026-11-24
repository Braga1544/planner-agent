import { LogOut } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "../auth";
import { CalendarSourcesSection } from "../components/CalendarSources";
import { ErrorBanner } from "../components/ErrorBanner";
import { cardClass, PageHeader, SectionHeader, secondaryButtonClass } from "../components/ui";
import { api } from "../lib/api";
import { keys } from "../lib/queryKeys";

const codeClass = "break-all rounded border border-border bg-bg px-1 py-px text-[0.8125rem] text-text";

export function SettingsPage() {
  const { logout } = useAuth();
  const me = useQuery({ queryKey: keys.me, queryFn: () => api.get<{ token_name: string }>("/me") });

  return (
    <div className="space-y-8">
      <PageHeader title="Einstellungen" />
      <section aria-label="Verbindung" className="space-y-1.5">
        <SectionHeader title="Verbindung" />
        <div className={`${cardClass} flex flex-wrap items-center gap-3 px-4 py-3`}>
          {me.isError ? (
            <div className="w-full">
              <ErrorBanner error={me.error} />
            </div>
          ) : (
            <p className="mr-auto flex items-center gap-2.5">
              <span aria-hidden="true" className={`size-2 rounded-full ${me.data ? "bg-accent" : "bg-muted/40"}`} />
              {me.data ? `Verbunden als ${me.data.token_name}` : "Prüfe Verbindung…"}
            </p>
          )}
          <button type="button" className={secondaryButtonClass} onClick={logout}>
            <LogOut aria-hidden="true" />
            Abmelden
          </button>
        </div>
      </section>
      <CalendarSourcesSection />
      <section aria-label="Kalender-Abo" className="space-y-1.5 text-sm">
        <SectionHeader title="Kalender-Abo (ICS-Feed)" />
        <div className={`${cardClass} px-4 py-3`}>
          <p className="leading-relaxed text-muted">
            Deine eigenen Termine kannst du in iCloud oder Outlook abonnieren:{" "}
            <code className={codeClass}>https://&lt;öffentliche Backend-Adresse&gt;/calendar/&lt;ICS_FEED_TOKEN&gt;.ics</code>. Den
            Token findest du in der Server-Konfiguration (<code className={codeClass}>ICS_FEED_TOKEN</code>).
          </p>
        </div>
      </section>
    </div>
  );
}
