import type { ReactNode } from "react";

export function AuthLayout({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  return (
    <div className="grid min-h-screen place-items-center bg-canvas px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6 text-center">
          <div className="text-2xl font-bold tracking-tight text-fg">
            Care<span className="text-accent-text">Nest</span> <span className="text-sm font-medium text-fg-muted">Admin</span>
          </div>
        </div>
        <div className="rounded-xl border border-border bg-surface p-6 shadow-popover">
          <h1 className="text-xl font-semibold text-fg">{title}</h1>
          {subtitle && <p className="mt-1 mb-4 text-sm text-fg-muted">{subtitle}</p>}
          <div className={subtitle ? "" : "mt-4"}>{children}</div>
        </div>
      </div>
    </div>
  );
}
