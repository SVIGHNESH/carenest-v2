import { Link, Outlet, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { CalendarClock, CircleHelp, Home, LogOut, Moon, Settings, Stethoscope, Sun, UserRound, Users } from "lucide-react";
import { useState } from "react";
import { api, tokenStore, unwrap } from "@/api/client";
import { applyTheme, currentTheme } from "@/lib/theme";
import { cn } from "@/lib/utils";

const NAV = [
  { to: "/", label: "Dashboard", icon: Home, exact: true },
  { to: "/bookings", label: "Bookings", icon: CalendarClock },
  { to: "/nurses", label: "Nurses", icon: Users },
  { to: "/services", label: "Services", icon: Stethoscope },
  { to: "/settings", label: "Settings", icon: Settings },
  { to: "/help", label: "Help", icon: CircleHelp },
] as const;

export function Shell() {
  const navigate = useNavigate();
  const [theme, setTheme] = useState(currentTheme());
  const me = useQuery({ queryKey: ["me"], queryFn: () => unwrap(api.GET("/admin/me")) });

  const signOut = () => {
    tokenStore.clear();
    navigate({ to: "/login" });
  };

  return (
    <div className="flex min-h-screen">
      <aside className="sticky top-0 hidden h-screen w-56 shrink-0 flex-col border-r border-border bg-surface md:flex">
        <div className="px-5 pt-5 pb-6">
          <div className="text-lg font-bold tracking-tight text-fg">
            Care<span className="text-accent-text">Nest</span>
          </div>
          <div className="text-2xs tracking-wider text-fg-muted uppercase">Admin</div>
        </div>
        <nav aria-label="Main" className="flex-1 space-y-0.5 px-3">
          {NAV.map(({ to, label, icon: Icon, ...rest }) => (
            <Link
              key={to}
              to={to}
              activeOptions={{ exact: "exact" in rest }}
              className="flex items-center gap-2.5 rounded-md px-2.5 py-1.5 text-sm text-fg-secondary hover:bg-surface-hover"
              activeProps={{ className: "bg-accent-soft !text-accent-text font-medium" }}
            >
              <Icon className="size-4" aria-hidden /> {label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-border p-3">
          <Link to="/profile" className="flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-surface-hover">
            <span className="grid size-7 place-items-center rounded-full bg-accent-soft text-xs font-semibold text-accent-text">
              {(me.data?.name || me.data?.email || "A").slice(0, 1).toUpperCase()}
            </span>
            <span className="min-w-0">
              <span className="block truncate text-sm font-medium text-fg">{me.data?.name || "Admin"}</span>
              <span className="block truncate text-xs text-fg-muted">{me.data?.email}</span>
            </span>
          </Link>
          <div className="mt-1 flex gap-1">
            <button
              onClick={() => {
                const next = theme === "dark" ? "light" : "dark";
                applyTheme(next);
                setTheme(next);
              }}
              className="flex flex-1 items-center justify-center gap-1.5 rounded-md py-1.5 text-xs text-fg-muted hover:bg-surface-hover"
              aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} theme`}
            >
              {theme === "dark" ? <Sun className="size-3.5" /> : <Moon className="size-3.5" />} Theme
            </button>
            <button onClick={signOut} className="flex flex-1 items-center justify-center gap-1.5 rounded-md py-1.5 text-xs text-fg-muted hover:bg-surface-hover">
              <LogOut className="size-3.5" /> Sign out
            </button>
          </div>
        </div>
      </aside>
      <div className="min-w-0 flex-1">
        <MobileBar />
        <main className="mx-auto max-w-6xl px-4 py-6 md:px-8 md:py-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

function MobileBar() {
  return (
    <nav aria-label="Main" className="sticky top-0 z-30 flex gap-1 overflow-x-auto border-b border-border bg-surface px-2 py-2 md:hidden">
      {NAV.map(({ to, label, ...rest }) => (
        <Link
          key={to}
          to={to}
          activeOptions={{ exact: "exact" in rest }}
          className={cn("rounded-md px-3 py-1.5 text-sm whitespace-nowrap text-fg-secondary")}
          activeProps={{ className: "bg-accent-soft !text-accent-text font-medium" }}
        >
          {label}
        </Link>
      ))}
      <Link to="/profile" className="rounded-md px-3 py-1.5 text-sm whitespace-nowrap text-fg-secondary" activeProps={{ className: "bg-accent-soft !text-accent-text" }}>
        <UserRound className="inline size-4" aria-label="Profile" />
      </Link>
    </nav>
  );
}
