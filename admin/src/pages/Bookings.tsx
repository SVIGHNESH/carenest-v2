import { useQuery } from "@tanstack/react-query";
import { Link, useNavigate, useSearch } from "@tanstack/react-router";
import { api, unwrap } from "@/api/client";
import { Badge, Button, Card, EmptyState, ErrorState, Loading, PageHeader, Select, Input, Table, Td, Th } from "@/components/ui";
import { formatShort, paymentInfo, statusInfo } from "@/lib/format";

const STATUSES = ["confirmed", "in_progress", "completed", "cancelled", "pending_payment", "expired"];

export function BookingsPage() {
  const search = useSearch({ from: "/app/bookings" });
  const navigate = useNavigate({ from: "/bookings" });
  const q = useQuery({
    queryKey: ["bookings", search],
    queryFn: () =>
      unwrap(api.GET("/admin/bookings", { params: { query: { status: search.status, q: search.q, nurse_id: search.nurse, day: search.day } } })),
  });
  const set = (patch: Partial<typeof search>) => navigate({ search: (s) => ({ ...s, ...patch }), replace: true });

  return (
    <>
      <PageHeader
        title="Bookings"
        description="Every paid booking arrives confirmed with a nurse. Your two actions are Reassign and Cancel."
        actions={
          <Link to="/bookings/nurse-unavailable">
            <Button variant="outline">Nurse unavailable (bulk)</Button>
          </Link>
        }
      />
      <div className="mb-4 flex flex-wrap gap-2">
        <Input className="w-64" placeholder="Search patient, phone or number" aria-label="Search bookings" defaultValue={search.q ?? ""} onChange={(e) => set({ q: e.target.value || undefined })} />
        <Select className="w-44" aria-label="Filter by status" value={search.status ?? ""} onChange={(e) => set({ status: e.target.value || undefined })}>
          <option value="">All except expired</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {statusInfo(s).label}
            </option>
          ))}
        </Select>
        <Input type="date" className="w-40" aria-label="Filter by day" value={search.day ?? ""} onChange={(e) => set({ day: e.target.value || undefined })} />
        {(search.status || search.q || search.day || search.nurse) && (
          <Button variant="ghost" onClick={() => navigate({ search: {}, replace: true })}>
            Clear filters
          </Button>
        )}
      </div>
      <Card>
        {q.isPending ? (
          <Loading />
        ) : q.isError ? (
          <ErrorState message={q.error.message} onRetry={() => q.refetch()} />
        ) : q.data.length === 0 ? (
          <EmptyState title="No bookings match" hint="Try clearing the filters." />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>#</Th>
                <Th>Patient</Th>
                <Th>When</Th>
                <Th>Asked for</Th>
                <Th>Nurse</Th>
                <Th>Status</Th>
                <Th>Payment</Th>
              </tr>
            </thead>
            <tbody>
              {q.data.map((b) => {
                const s = statusInfo(b.status);
                const p = paymentInfo(b.payment_status);
                return (
                  <tr key={b.id} className="hover:bg-surface-hover">
                    <Td>
                      <Link to="/bookings/$id" params={{ id: String(b.id) }} className="font-medium text-accent-text hover:underline">
                        {b.id}
                      </Link>
                    </Td>
                    <Td>
                      <div className="font-medium">{b.patient_name || "-"}</div>
                      <div className="text-xs text-fg-muted">{b.service_name}</div>
                    </Td>
                    <Td>
                      <div>{formatShort(b.slot_start)}</div>
                      <div className="text-xs text-fg-muted">
                        {b.hours} {b.hours === 1 ? "hour" : "hours"}
                      </div>
                    </Td>
                    <Td className="capitalize">{b.nurse_gender_preference}</Td>
                    <Td>{b.nurse?.name ?? <span className="text-fg-muted">-</span>}</Td>
                    <Td>
                      <Badge tone={s.tone}>{s.label}</Badge>
                      {b.cancel_reason && <div className="mt-0.5 max-w-44 truncate text-xs text-fg-muted">{b.cancel_reason}</div>}
                    </Td>
                    <Td>
                      <Badge tone={p.tone}>{p.label}</Badge>
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        )}
      </Card>
    </>
  );
}
