/** Display helpers. Slot times from the API are naive IST wall-clock strings. */

export type Tone = "success" | "info" | "warning" | "special" | "danger" | "neutral";

const STATUS: Record<string, { label: string; tone: Tone }> = {
  pending_payment: { label: "Awaiting payment", tone: "warning" },
  expired: { label: "Expired", tone: "neutral" },
  confirmed: { label: "Confirmed", tone: "info" },
  in_progress: { label: "In progress", tone: "special" },
  completed: { label: "Completed", tone: "success" },
  cancelled: { label: "Cancelled", tone: "danger" },
};

const PAYMENT: Record<string, { label: string; tone: Tone }> = {
  pending: { label: "Unpaid", tone: "warning" },
  completed: { label: "Paid", tone: "success" },
  refund_pending: { label: "Refund in progress", tone: "warning" },
  refunded: { label: "Refunded", tone: "neutral" },
  refund_failed: { label: "Refund failed", tone: "danger" },
};

export const statusInfo = (s: string) => STATUS[s] ?? { label: s, tone: "neutral" as Tone };
export const paymentInfo = (s: string | null | undefined) =>
  s ? (PAYMENT[s] ?? { label: s, tone: "neutral" as Tone }) : { label: "No payment", tone: "neutral" as Tone };

export const isOpen = (status: string) => status === "confirmed" || status === "in_progress" || status === "pending_payment";

export function rupees(n: number) {
  return `Rs ${n.toLocaleString("en-IN")}`;
}

export function hourLabel(h: number) {
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:00 ${h < 12 || h === 24 ? "AM" : "PM"}`;
}

export function parseSlot(iso: string): Date {
  // Treated as local wall-clock on purpose: the string carries no zone.
  const [d, t = "00:00:00"] = iso.split("T");
  const [y, m, day] = d.split("-").map(Number);
  const [hh, mm] = t.split(":").map(Number);
  return new Date(y, m - 1, day, hh, mm);
}

const DAY = new Intl.DateTimeFormat("en-IN", { weekday: "short", day: "numeric", month: "short" });

export function formatSlot(startIso: string, hours: number) {
  const s = parseSlot(startIso);
  return `${DAY.format(s)}, ${hourLabel(s.getHours())}, ${hours} ${hours === 1 ? "hour" : "hours"}`;
}

export function formatShort(startIso: string) {
  const s = parseSlot(startIso);
  return `${s.getDate()} ${s.toLocaleString("en-IN", { month: "short" })}, ${hourLabel(s.getHours())}`;
}

export function formatInstant(iso: string) {
  return new Date(iso).toLocaleString("en-IN", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit", timeZone: "Asia/Kolkata" });
}

const ACTIONS: Record<string, string> = {
  booking_created: "Booking created",
  booking_confirmed: "Payment received, booking confirmed",
  auto_cancelled_no_nurse: "Auto-cancelled: no nurse was free after payment",
  booking_cancelled: "Booking cancelled",
  nurse_reassigned: "Nurse reassigned",
  visit_started: "Visit started",
  visit_completed: "Visit completed",
  status_corrected: "Status corrected",
};

export function actionLabel(action: string) {
  return ACTIONS[action] ?? action.replaceAll("_", " ");
}

export function actorLabel(actor: string) {
  if (actor === "system") return "automatic";
  const m = /^admin:\d+ (.+)$/.exec(actor);
  if (m) return m[1];
  return actor.startsWith("user:") ? "customer" : actor;
}

export const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export function hoursSummary(rows: { weekday: number; start_hour: number; end_hour: number }[]) {
  if (rows.length === 0) return "Not set";
  const groups = new Map<string, number[]>();
  for (const r of rows) {
    const k = `${r.start_hour}-${r.end_hour}`;
    groups.set(k, [...(groups.get(k) ?? []), r.weekday]);
  }
  return [...groups.entries()]
    .map(([k, days]) => {
      const [s, e] = k.split("-").map(Number);
      const sorted = [...days].sort();
      const contiguous = sorted.every((d, i) => i === 0 || d === sorted[i - 1] + 1);
      const label =
        sorted.length === 1 ? WEEKDAYS[sorted[0]] : contiguous ? `${WEEKDAYS[sorted[0]]} to ${WEEKDAYS[sorted[sorted.length - 1]]}` : sorted.map((d) => WEEKDAYS[d]).join(", ");
      return `${label}, ${hourLabel(s)} to ${hourLabel(e)}`;
    })
    .join("; ");
}
