import {
  Briefcase,
  CalendarDays,
  Palette,
  House,
  LayoutGrid,
  MessageSquare,
  Rocket,
  Search,
  Settings,
  Sun,
  type LucideIcon,
} from "lucide-react";
import { useState, type FormEvent } from "react";
import { NavLink, Outlet, useMatch, useNavigate } from "react-router";
import { AREAS, type AreaSlug } from "../lib/types";
import { inputClass } from "./ui";

const MAIN_NAV: Array<{ to: string; label: string; icon: LucideIcon }> = [
  { to: "/", label: "Heute", icon: Sun },
  { to: "/chat", label: "Chat", icon: MessageSquare },
  { to: "/kalender", label: "Kalender", icon: CalendarDays },
  { to: "/einstellungen", label: "Einstellungen", icon: Settings },
];

const AREA_ICONS: Record<AreaSlug, LucideIcon> = {
  work: Briefcase,
  business: Rocket,
  hobby: Palette,
  personal: House,
};

function sideNavClass({ isActive }: { isActive: boolean }) {
  return `flex items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40 ${
    isActive ? "bg-accent-soft font-medium text-accent" : "text-text/80 hover:bg-bg hover:text-text"
  }`;
}

function SideLink({ to, label, icon: Icon, end }: { to: string; label: string; icon: LucideIcon; end?: boolean }) {
  return (
    <NavLink to={to} end={end} className={sideNavClass}>
      <Icon aria-hidden="true" className="size-4 shrink-0" strokeWidth={1.75} />
      {label}
    </NavLink>
  );
}

function tabClass(active: boolean) {
  return `flex min-w-0 flex-1 flex-col items-center justify-center gap-0.5 py-1.5 text-[0.6875rem] font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-accent/40 ${
    active ? "text-accent" : "text-muted hover:text-text"
  }`;
}

function BottomTab({ to, label, icon: Icon, end, active }: { to: string; label: string; icon: LucideIcon; end?: boolean; active?: boolean }) {
  return (
    <NavLink to={to} end={end} className={({ isActive }) => tabClass(active ?? isActive)}>
      {({ isActive }) => (
        <>
          <Icon aria-hidden="true" className="size-5" strokeWidth={(active ?? isActive) ? 2 : 1.75} />
          <span className="max-w-full truncate">{label}</span>
        </>
      )}
    </NavLink>
  );
}

export function Layout() {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const inArea = useMatch("/bereiche/*") !== null;
  const inProject = useMatch("/projekte/*") !== null;

  function search(event: FormEvent) {
    event.preventDefault();
    const q = query.trim();
    if (q) navigate(`/suche?q=${encodeURIComponent(q)}`);
  }

  return (
    <div className="min-h-screen md:flex">
      <aside className="hidden md:sticky md:top-0 md:flex md:h-screen md:w-60 md:shrink-0 md:flex-col md:gap-0.5 md:overflow-y-auto md:border-r md:border-border md:bg-surface md:px-3 md:py-5">
        <div className="mb-5 px-2.5 text-[0.9375rem] font-semibold tracking-tight">Planungs-Agent</div>
        {MAIN_NAV.map((item) => (
          <SideLink key={item.to} to={item.to} label={item.label} icon={item.icon} end={item.to === "/"} />
        ))}
        <div className="mb-1 mt-6 px-2.5 text-xs font-medium text-muted">Bereiche</div>
        {AREAS.map((area) => (
          <SideLink key={area.slug} to={`/bereiche/${area.slug}`} label={area.name} icon={AREA_ICONS[area.slug]} />
        ))}
      </aside>

      <div className="min-w-0 flex-1 pb-[calc(4rem+env(safe-area-inset-bottom))] md:pb-0">
        <header className="border-b border-border px-4 py-3 md:px-8">
          <div className="flex max-w-3xl items-center gap-3">
            <span className="shrink-0 text-[0.9375rem] font-semibold tracking-tight md:hidden">Planungs-Agent</span>
            <form role="search" onSubmit={search} className="relative min-w-0 flex-1">
              <Search aria-hidden="true" className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted" />
              <input
                type="search"
                aria-label="Suche"
                placeholder="Suchen…"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                className={`${inputClass} pl-9`}
              />
            </form>
          </div>
        </header>
        <main className="max-w-3xl px-4 py-6 md:px-8 md:py-8">
          <Outlet />
        </main>
      </div>

      <nav className="fixed inset-x-0 bottom-0 z-40 flex border-t border-border bg-surface/95 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden">
        <div className="flex h-16 w-full">
          {MAIN_NAV.slice(0, 3).map((item) => (
            <BottomTab key={item.to} to={item.to} label={item.label} icon={item.icon} end={item.to === "/"} />
          ))}
          <BottomTab to="/bereiche/work" label="Bereiche" icon={LayoutGrid} active={inArea || inProject} />
          <BottomTab to={MAIN_NAV[3].to} label={MAIN_NAV[3].label} icon={MAIN_NAV[3].icon} />
        </div>
      </nav>
    </div>
  );
}
