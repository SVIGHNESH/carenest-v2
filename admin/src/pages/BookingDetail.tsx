import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useParams } from "@tanstack/react-router";
import { ArrowLeft, ExternalLink, RotateCw } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { api, type Schemas, unwrap } from "@/api/client";
import { Badge, Button, Card, CardHeader, DefList, Dialog, ErrorState, Field, Loading, Textarea } from "@/components/ui";
import { actionLabel, actorLabel, formatInstant, formatSlot, isOpen, paymentInfo, rupees, statusInfo } from "@/lib/format";

type Detail = Schemas["AdminBookingDetail"];
const MAPS_KEY = import.meta.env.VITE_GOOGLE_MAPS_EMBED_KEY as string | undefined;

export function BookingDetailPage() {
  const { id } = useParams({ from: "/app/bookings/$id" });
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ["booking", id], queryFn: () => unwrap(api.GET("/admin/bookings/{booking_id}", { params: { path: { booking_id: Number(id) } } })) });
  const [dialog, setDialog] = useState<"reassign" | "cancel" | null>(null);
  const refresh = (d: Detail) => {
    qc.setQueryData(["booking", id], d);
    qc.invalidateQueries({ queryKey: ["bookings"] });
    qc.invalidateQueries({ queryKey: ["dashboard"] });
  };

  const resend = useMutation({
    mutationFn: (mid: number) => unwrap(api.POST("/admin/messages/{message_id}/resend", { params: { path: { message_id: mid } } })),
    onSuccess: (m) => {
      toast.success(m.status === "sent" ? "Message sent" : "Message queued again");
      qc.invalidateQueries({ queryKey: ["booking", id] });
    },
    onError: (e) => toast.error(e.message),
  });
  const setStatus = useMutation({
    mutationFn: (status: "in_progress" | "completed") => unwrap(api.POST("/admin/bookings/{booking_id}/status", { params: { path: { booking_id: Number(id) } }, body: { status } })),
    onSuccess: (d) => {
      refresh(d);
      toast.success("Status updated");
    },
    onError: (e) => toast.error(e.message),
  });

  if (q.isPending) return <Loading />;
  if (q.isError) return <ErrorState message={q.error.message} onRetry={() => q.refetch()} />;
  const b = q.data;
  const s = statusInfo(b.status);
  const p = paymentInfo(b.payment_status);
  const open = isOpen(b.status);
  const live = b.status === "confirmed" || b.status === "in_progress";

  return (
    <>
      <Link to="/bookings" className="mb-3 inline-flex items-center gap-1 text-sm text-fg-muted hover:text-fg">
        <ArrowLeft className="size-4" /> Bookings
      </Link>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-semibold">Booking #{b.id}</h1>
          <Badge tone={s.tone}>{s.label}</Badge>
        </div>
        <div className="flex gap-2">
          {live && (
            <Button variant="outline" onClick={() => setDialog("reassign")}>
              Reassign nurse
            </Button>
          )}
          {open && (
            <Button variant="danger" onClick={() => setDialog("cancel")}>
              Cancel booking
            </Button>
          )}
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader title="Booking" />
          <div className="p-4">
            <DefList
              rows={[
                ["Visit", formatSlot(b.slot_start, b.hours)],
                ["Patient", [b.patient_name, b.patient_age, b.patient_sex].filter(Boolean).join(", ") || "-"],
                ["Patient phone", <a className="text-accent-text hover:underline" href={`tel:${b.contact_phone}`}>{b.contact_phone || "-"}</a>],
                ["Booked by", b.user_phone ?? "Deleted account"],
                ["Notes", b.patient_condition || "-"],
                ["Payment", <span className="inline-flex items-center gap-2">{rupees(b.amount)} <Badge tone={p.tone}>{p.label}</Badge></span>],
                ...(b.payment?.refund_error ? ([["Refund error", <span className="text-danger">{b.payment.refund_error}</span>]] as [string, React.ReactNode][]) : []),
                ...(b.cancel_reason ? ([["Cancelled", `${b.cancel_reason} (${b.cancelled_by})`]] as [string, React.ReactNode][]) : []),
              ]}
            />
          </div>
        </Card>

        <Card>
          <CardHeader
            title="Nurse"
            action={
              b.status === "confirmed" || b.status === "in_progress" ? (
                <div className="flex gap-1">
                  {b.status === "confirmed" && (
                    <Button size="sm" variant="ghost" onClick={() => setStatus.mutate("in_progress")}>
                      Mark started
                    </Button>
                  )}
                  <Button size="sm" variant="ghost" onClick={() => setStatus.mutate("completed")}>
                    Mark completed
                  </Button>
                </div>
              ) : undefined
            }
          />
          <div className="p-4">
            <DefList
              rows={[
                ["User asked for", <span className="capitalize">{b.nurse_gender_preference} nurse</span>],
                ["Assigned", b.nurse ? `${b.nurse.name} (${b.nurse.phone})` : "No nurse assigned"],
                ["Visit link", b.visit_link_opened_at ? `Opened ${formatInstant(b.visit_link_opened_at)}` : live ? "Not opened yet" : "-"],
              ]}
            />
            <h3 className="mt-5 mb-2 text-xs font-medium text-fg-muted">Messages</h3>
            {b.messages.length === 0 ? (
              <p className="text-sm text-fg-muted">None yet.</p>
            ) : (
              <ul className="divide-y divide-border rounded-md border border-border">
                {b.messages.map((m) => (
                  <li key={m.id} className="flex items-center gap-2 px-3 py-2 text-sm">
                    <div className="min-w-0 flex-1">
                      <span className="font-medium">{m.template.replaceAll("_", " ")}</span>{" "}
                      <span className="text-fg-muted">
                        to {m.recipient_type} by {m.channel}
                      </span>
                      {m.last_error && <div className="truncate text-xs text-danger">{m.last_error}</div>}
                    </div>
                    <Badge tone={m.status === "sent" ? "success" : m.status === "failed" ? "danger" : "warning"}>{m.status}</Badge>
                    {m.recipient_type !== "admin" && (
                      <Button size="sm" variant="ghost" aria-label={`Resend ${m.template}`} onClick={() => resend.mutate(m.id)} loading={resend.isPending && resend.variables === m.id}>
                        <RotateCw className="size-3.5" /> Resend
                      </Button>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </Card>

        <Card>
          <CardHeader title="Visit location" action={<a className="inline-flex items-center gap-1 text-sm text-accent-text hover:underline" href={b.maps_url} target="_blank" rel="noreferrer"><ExternalLink className="size-3.5" /> Open in Google Maps</a>} />
          <div className="space-y-3 p-4">
            <DefList rows={[["Address", b.address_text || "-"], ["Landmark", b.address_landmark || "-"], ["Pin", `${b.latitude.toFixed(5)}, ${b.longitude.toFixed(5)}`]]} />
            {MAPS_KEY ? (
              <iframe title="Visit location map" className="h-56 w-full rounded-md border border-border" loading="lazy" src={`https://www.google.com/maps/embed/v1/place?key=${MAPS_KEY}&q=${b.latitude},${b.longitude}`} />
            ) : (
              <div className="grid h-40 place-items-center rounded-md border border-dashed border-border-strong bg-surface-sunken text-center text-xs text-fg-muted">
                Map preview needs a Google Maps Embed key
                <br />
                (VITE_GOOGLE_MAPS_EMBED_KEY). The link above works without one.
              </div>
            )}
          </div>
        </Card>

        <Card>
          <CardHeader title="History" />
          <ol className="space-y-3 p-4">
            {b.history.map((h) => (
              <li key={h.id} className="text-sm">
                <div className="font-medium">{actionLabel(h.action)}</div>
                <div className="text-xs text-fg-muted">
                  {formatInstant(h.created_at)}, {actorLabel(h.actor)}
                  {typeof h.details?.reason === "string" ? `, "${h.details.reason}"` : ""}
                </div>
              </li>
            ))}
          </ol>
        </Card>
      </div>

      {dialog === "cancel" && <CancelDialog b={b} onClose={() => setDialog(null)} onDone={refresh} />}
      {dialog === "reassign" && <ReassignDialog b={b} onClose={() => setDialog(null)} onDone={refresh} />}
    </>
  );
}

export function CancelDialog({ b, onClose, onDone }: { b: Detail; onClose: () => void; onDone: (d: Detail) => void }) {
  const [reason, setReason] = useState("");
  const paid = b.payment && ["completed", "refund_pending", "refund_failed"].includes(b.payment.status);
  const m = useMutation({
    mutationFn: () => unwrap(api.POST("/admin/bookings/{booking_id}/cancel", { params: { path: { booking_id: b.id } }, body: { reason: reason.trim() } })),
    onSuccess: (d) => {
      onDone(d);
      onClose();
      toast.success(d.payment?.status === "refund_failed" ? "Cancelled, but the refund failed. See Needs attention." : "Booking cancelled");
    },
    onError: (e) => toast.error(e.message),
  });
  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={`Cancel booking #${b.id}?`}
      description="This cannot be undone."
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Keep booking
          </Button>
          <Button variant="danger" disabled={!reason.trim()} loading={m.isPending} onClick={() => m.mutate()}>
            {paid ? "Cancel booking and refund" : "Cancel booking"}
          </Button>
        </>
      }
    >
      <DefList rows={[["Patient", b.patient_name || "-"], ["Visit", formatSlot(b.slot_start, b.hours)], ["Nurse", b.nurse?.name ?? "-"], ["Refund to user", paid ? `${rupees(b.amount)} (full)` : "Nothing paid"]]} />
      <div className="mt-4">
        <Field label="Reason (required, shown to the user)" htmlFor="reason">
          <Textarea id="reason" value={reason} maxLength={40} onChange={(e) => setReason(e.target.value)} placeholder="e.g. nurse unwell" />
        </Field>
        <p className="mt-1 text-xs text-fg-muted">Up to 40 characters, because it goes into an SMS.</p>
      </div>
      <h3 className="mt-4 mb-1 text-xs font-medium text-fg-muted">What happens next</h3>
      <ul className="list-disc space-y-0.5 pl-5 text-sm text-fg-secondary">
        <li>The booking is cancelled and the nurse's time is freed</li>
        {paid && <li>The refund is sent automatically</li>}
        {paid && <li>The user gets an SMS with the reason and refund note</li>}
        {b.nurse && <li>{b.nurse.name} gets an SMS that the visit is off</li>}
        <li>Your name, the time and the reason are recorded</li>
      </ul>
    </Dialog>
  );
}

function ReassignDialog({ b, onClose, onDone }: { b: Detail; onClose: () => void; onDone: (d: Detail) => void }) {
  const [pick, setPick] = useState<number | null>(null);
  const cands = useQuery({
    queryKey: ["candidates", b.id],
    queryFn: () => unwrap(api.GET("/admin/bookings/{booking_id}/reassign-candidates", { params: { path: { booking_id: b.id } } })),
  });
  const m = useMutation({
    mutationFn: () => unwrap(api.POST("/admin/bookings/{booking_id}/reassign", { params: { path: { booking_id: b.id } }, body: { nurse_id: pick! } })),
    onSuccess: (d) => {
      onDone(d);
      onClose();
      toast.success("Nurse reassigned");
    },
    onError: (e) => toast.error(e.message),
  });
  const chosen = cands.data?.find((c) => c.id === pick);
  return (
    <Dialog
      open
      wide
      onOpenChange={(o) => !o && onClose()}
      title={`Reassign nurse for booking #${b.id}`}
      description={`${formatSlot(b.slot_start, b.hours)}. User asked for a ${b.nurse_gender_preference} nurse.`}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
          <Button disabled={pick === null} loading={m.isPending} onClick={() => m.mutate()}>
            Reassign
          </Button>
        </>
      }
    >
      {cands.isPending ? (
        <Loading />
      ) : cands.isError ? (
        <ErrorState message={cands.error.message} />
      ) : cands.data.length === 0 ? (
        <p className="text-sm text-fg-muted">No other active nurses.</p>
      ) : (
        <fieldset>
          <legend className="sr-only">Choose a nurse</legend>
          <ul className="divide-y divide-border rounded-md border border-border">
            {cands.data.map((c) => {
              const ok = c.free;
              return (
                <li key={c.id}>
                  <label className={`flex items-center gap-3 px-3 py-2.5 text-sm ${ok ? "cursor-pointer hover:bg-surface-hover" : "opacity-60"}`}>
                    <input type="radio" name="nurse" disabled={!ok} checked={pick === c.id} onChange={() => setPick(c.id)} className="accent-[var(--accent)]" />
                    <span className="flex-1 font-medium">{c.name}</span>
                    <span className="w-16 capitalize text-fg-muted">{c.gender}</span>
                    <span className="flex flex-wrap justify-end gap-1">
                      {!c.same_gender && <Badge tone="warning">Different gender</Badge>}
                      {!c.qualified && <Badge tone="warning">Not qualified</Badge>}
                      <Badge tone={ok ? "success" : "neutral"}>{ok ? "Free" : c.on_duty ? "Busy" : "Off duty"}</Badge>
                    </span>
                  </label>
                </li>
              );
            })}
          </ul>
        </fieldset>
      )}
      <h3 className="mt-4 mb-1 text-xs font-medium text-fg-muted">What happens next</h3>
      <ul className="list-disc space-y-0.5 pl-5 text-sm text-fg-secondary">
        {b.nurse && <li>{b.nurse.name} gets an SMS that the visit is removed</li>}
        <li>{chosen ? chosen.name : "The new nurse"} gets the visit details by SMS and email</li>
        <li>The user gets an SMS with the new nurse name</li>
      </ul>
    </Dialog>
  );
}
