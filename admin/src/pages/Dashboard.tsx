import { useQuery } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import { AlertTriangle } from "lucide-react";
import { api, unwrap } from "@/api/client";
import { Badge, Card, CardHeader, EmptyState, ErrorState, Loading, PageHeader } from "@/components/ui";
import { formatShort, hourLabel, parseSlot, statusInfo } from "@/lib/format";

export function DashboardPage() {
  const q = useQuery({ queryKey: ["dashboard"], queryFn: () => unwrap(api.GET("/admin/dashboard")), refetchInterval: 60_000 });
  if (q.isPending) return <Loading />;
  if (q.isError) return <ErrorState message={q.error.message} onRetry={() => q.refetch()} />;
  const { attention, today } = q.data;
  const visits = today.flatMap((n) => n.visits);
  const stats = [
    { label: "Visits today", value: visits.length },
    { label: "In progress now", value: visits.filter((v) => v.status === "in_progress").length },
    { label: "Nurses on duty", value: today.length },
    { label: "Need attention", value: attention.length, alert: attention.length > 0 },
  ];
  return (
    <>
      <PageHeader title="Dashboard" description="Bookings confirm themselves once paid. This page shows only what the system could not finish alone." />
      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
        {stats.map((s) => (
          <Card key={s.label} className="p-4">
            <div className={`text-2xl font-semibold ${s.alert ? "text-danger" : "text-fg"}`}>{s.value}</div>
            <div className="mt-0.5 text-xs text-fg-muted">{s.label}</div>
          </Card>
        ))}
      </div>

      <Card className="mb-6">
        <CardHeader title="Needs attention" />
        {attention.length === 0 ? (
          <EmptyState title="All clear" hint="No failed refunds, auto-cancellations or undelivered nurse messages." />
        ) : (
          <ul>
            {attention.map((a, i) => (
              <li key={i} className="flex items-start gap-3 border-b border-border px-4 py-3 last:border-0">
                <AlertTriangle className="mt-0.5 size-4 shrink-0 text-warning" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-fg">{a.title}</p>
                  <p className="text-sm text-fg-muted">{a.detail}</p>
                </div>
                {a.booking_id ? (
                  <Link to="/bookings/$id" params={{ id: String(a.booking_id) }} className="text-sm font-medium text-accent-text hover:underline">
                    Open
                  </Link>
                ) : a.nurse_id ? (
                  <Link to="/nurses/$id/availability" params={{ id: String(a.nurse_id) }} className="text-sm font-medium text-accent-text hover:underline">
                    Set hours
                  </Link>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card>
        <CardHeader title="Today by nurse" />
        {today.length === 0 ? (
          <EmptyState title="No visits today" />
        ) : (
          <ul>
            {today.map((n) => {
              const next = n.visits.find((v) => parseSlot(v.slot_end) > new Date() && v.status !== "cancelled") ?? n.visits[0];
              return (
                <li key={n.nurse_id} className="flex flex-wrap items-center gap-3 border-b border-border px-4 py-3 last:border-0">
                  <div className="w-40 font-medium text-fg">{n.nurse_name}</div>
                  <Badge tone="info">
                    {n.visits.length} {n.visits.length === 1 ? "visit" : "visits"}
                  </Badge>
                  <div className="min-w-0 flex-1 text-sm text-fg-muted">
                    {hourLabel(parseSlot(next.slot_start).getHours())}, {next.patient_name || "Patient"} <span className="text-fg-subtle">({statusInfo(next.status).label})</span>
                  </div>
                  <Link to="/bookings" search={{ nurse: n.nurse_id, day: new Date().toISOString().slice(0, 10) }} className="text-sm font-medium text-accent-text hover:underline">
                    View day
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
        <p className="border-t border-border bg-surface-sunken px-4 py-2.5 text-xs text-fg-muted">
          Nurses have no app. If a nurse says an SMS never arrived, open the booking and resend it, or read the day out from here. Last visit today ends {visits.length ? formatShort(visits[visits.length - 1].slot_end) : "-"}.
        </p>
      </Card>
    </>
  );
}
