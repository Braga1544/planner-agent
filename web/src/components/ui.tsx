import { Children, type ReactNode } from "react";

const focusRing = "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40";

const fieldBase =
  "min-h-10 sm:min-h-9 rounded-lg border border-border bg-surface px-3 py-1.5 text-base text-text sm:text-sm " +
  "placeholder:text-muted transition-colors hover:border-muted/50 focus-visible:border-accent " +
  `${focusRing} disabled:cursor-not-allowed disabled:opacity-60`;
export const inputClass = `w-full ${fieldBase}`;
export const compactInputClass = `w-auto ${fieldBase}`;

const buttonBase =
  "inline-flex min-h-10 sm:min-h-9 shrink-0 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg px-3.5 text-sm font-medium " +
  `transition-colors ${focusRing} disabled:cursor-not-allowed disabled:opacity-50 [&_svg]:size-4 [&_svg]:shrink-0`;

export const buttonClass = `${buttonBase} bg-accent text-on-accent hover:bg-accent/90`;
export const secondaryButtonClass = `${buttonBase} border border-border bg-surface text-text hover:bg-bg`;
export const ghostButtonClass = `${buttonBase} text-muted hover:bg-bg hover:text-text`;
export const dangerButtonClass = `${buttonBase} border border-danger/30 bg-surface text-danger hover:bg-danger/5`;
// don't forget aria-label
export const iconButtonClass =
  `inline-flex size-9 shrink-0 items-center justify-center rounded-full text-muted transition-colors hover:bg-bg hover:text-text ` +
  `${focusRing} disabled:cursor-not-allowed disabled:opacity-50 [&_svg]:size-[18px]`;

export const cardClass = "rounded-xl border border-border bg-surface";
const sectionTitleBase = "text-[0.8125rem] font-semibold";
export const pageTitleClass = "text-2xl font-semibold tracking-tight";
export const linkClass = `rounded text-accent underline-offset-2 hover:underline ${focusRing}`;

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block text-sm">
      <span className="mb-1.5 block font-medium text-muted">{label}</span>
      {children}
    </label>
  );
}

export function PageHeader({ title, subtitle, children }: { title: ReactNode; subtitle?: ReactNode; children?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end gap-x-4 gap-y-3">
      <div className="mr-auto min-w-0">
        <h1 className={pageTitleClass}>{title}</h1>
        {subtitle && <p className="mt-0.5 text-sm text-muted">{subtitle}</p>}
      </div>
      {children}
    </div>
  );
}

export function SectionHeader({ title, tone, children }: { title: string; tone?: "danger"; children?: ReactNode }) {
  return (
    <div className="flex min-h-9 items-center justify-between gap-3 px-1">
      <h2 className={`${sectionTitleBase} ${tone === "danger" ? "text-danger" : "text-muted"}`}>{title}</h2>
      {children}
    </div>
  );
}

export function Section({
  title,
  empty,
  tone,
  label,
  children,
}: {
  title: string;
  label?: string;
  empty?: string;
  tone?: "danger";
  children?: ReactNode;
}) {
  const count = Children.count(children);
  return (
    <section aria-label={label ?? title} className="space-y-1.5">
      <SectionHeader title={title} tone={tone} />
      {count > 0 ? (
        <ul className={`${cardClass} divide-y divide-border overflow-hidden`}>{children}</ul>
      ) : empty ? (
        <p className="px-1 text-sm text-muted">{empty}</p>
      ) : null}
    </section>
  );
}
