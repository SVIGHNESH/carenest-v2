import { createRootRoute, createRoute, createRouter, redirect, Outlet } from "@tanstack/react-router";
import { tokenStore } from "@/api/client";
import { Shell } from "@/components/Shell";
import { AvailabilityPage } from "@/pages/Availability";
import { BookingDetailPage } from "@/pages/BookingDetail";
import { BookingsPage } from "@/pages/Bookings";
import { DashboardPage } from "@/pages/Dashboard";
import { HelpPage } from "@/pages/Help";
import { LoginPage } from "@/pages/Login";
import { NurseUnavailablePage } from "@/pages/NurseUnavailable";
import { NursesPage } from "@/pages/Nurses";
import { ProfilePage } from "@/pages/Profile";
import { ForgotPasswordPage, ResetPasswordPage } from "@/pages/Recover";
import { ServicesPage } from "@/pages/Services";
import { SettingsPage } from "@/pages/Settings";

const root = createRootRoute({ component: Outlet });

const login = createRoute({ getParentRoute: () => root, path: "/login", component: LoginPage });
const forgot = createRoute({ getParentRoute: () => root, path: "/forgot-password", component: ForgotPasswordPage });
const reset = createRoute({
  getParentRoute: () => root,
  path: "/reset-password",
  component: ResetPasswordPage,
  validateSearch: (s: Record<string, unknown>) => ({ token: typeof s.token === "string" ? s.token : undefined }),
});

const app = createRoute({
  getParentRoute: () => root,
  id: "app",
  component: Shell,
  beforeLoad: () => {
    if (!tokenStore.get()) throw redirect({ to: "/login" });
  },
});

const dashboard = createRoute({ getParentRoute: () => app, path: "/", component: DashboardPage });
const bookings = createRoute({
  getParentRoute: () => app,
  path: "/bookings",
  component: BookingsPage,
  validateSearch: (s: Record<string, unknown>): { status?: string; q?: string; day?: string; nurse?: number } => ({
    status: typeof s.status === "string" ? s.status : undefined,
    q: typeof s.q === "string" ? s.q : undefined,
    day: typeof s.day === "string" ? s.day : undefined,
    nurse: s.nurse !== undefined && !Number.isNaN(Number(s.nurse)) ? Number(s.nurse) : undefined,
  }),
});
const bulk = createRoute({ getParentRoute: () => app, path: "/bookings/nurse-unavailable", component: NurseUnavailablePage });
const bookingDetail = createRoute({ getParentRoute: () => app, path: "/bookings/$id", component: BookingDetailPage });
const nurses = createRoute({ getParentRoute: () => app, path: "/nurses", component: NursesPage });
const availability = createRoute({ getParentRoute: () => app, path: "/nurses/$id/availability", component: AvailabilityPage });
const services = createRoute({ getParentRoute: () => app, path: "/services", component: ServicesPage });
const settings = createRoute({ getParentRoute: () => app, path: "/settings", component: SettingsPage });
const profile = createRoute({ getParentRoute: () => app, path: "/profile", component: ProfilePage });
const help = createRoute({ getParentRoute: () => app, path: "/help", component: HelpPage });

const tree = root.addChildren([login, forgot, reset, app.addChildren([dashboard, bookings, bulk, bookingDetail, nurses, availability, services, settings, profile, help])]);

export const router = createRouter({ routeTree: tree, defaultPreload: "intent" });

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
