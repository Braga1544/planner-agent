import { X } from "lucide-react";
import { useEffect, type ReactNode } from "react";
import { iconButtonClass } from "./ui";

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/30 p-3 backdrop-blur-[2px] motion-safe:animate-backdrop-in sm:items-center sm:p-4"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="max-h-[90dvh] w-full max-w-lg overflow-y-auto rounded-2xl border border-border bg-surface p-5 shadow-xl shadow-black/10 motion-safe:animate-dialog-in sm:p-6"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="mb-5 flex items-start justify-between gap-4">
          <h2 className="pt-1 text-lg font-semibold tracking-tight">{title}</h2>
          <button type="button" aria-label="Schließen" onClick={onClose} className={`${iconButtonClass} -mr-2 -mt-1`}>
            <X aria-hidden="true" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function ModalFooter({ start, children }: { start?: ReactNode; children: ReactNode }) {
  return (
    <div className="-mx-5 mt-2 flex items-center justify-between gap-2 border-t border-border px-5 pt-4 sm:-mx-6 sm:px-6">
      {start ?? <span />}
      <div className="flex items-center gap-2">{children}</div>
    </div>
  );
}
