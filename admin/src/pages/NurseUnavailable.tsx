import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { api, unwrap } from "@/api/client";
import { Badge, Button, Card, CardHeader, EmptyState, Field, Input, PageHeader, Select, Table, Td, Th, Textarea } from "@/components/ui";
import { formatShort } from "@/lib/format";

const today = () => new Date().toISOString().slice(0, 10);

export function NurseUnavailablePage() {
  const nurses = useQuery({ queryKey: ["nurses"], queryFn: () => unwrap(api.GET("/admin/nurses")) });
  const [nurseId, setNurseId] = useState<number | "">("");
  const [from, setFrom] = useState(today());
  const [to, setTo] = useState(today());
  const [note, setNote] = useState("");
  const qc = useQueryClient();
  const navigate = useNavigate();
  const body = { from_day: from, to_day: to, note: note.trim() || undefined };

  const preview = useMutation({
    mutationFn: () => unwrap(api.POST("/admin/nurses/{nurse_id}/unavailable", { params: { path: { nurse_id: Number(nurseId) } }, body: { ...body, apply: false } })),
    onError: (e) => toast.error(e.message),
  });
  const apply = useMutation({
    mutationFn: () => unwrap(api.POST("/admin/nurses/{nurse_id}/unavailable", { params: { path: { nurse_id: Number(nurseId) } }, body: { ...body, apply: true } })),
    onSuccess: (r) => {
      toast.success(`Done. ${r.items.length} booking${r.items.length === 1 ? "" : "s"} handled and leave marked.`);
      qc.invalidateQueries();
      navigate({ to: "/bookings" });
    },
    onError: (e) => toast.error(e.message),
  });
  const items = preview.data?.items;
  const valid = nurseId !== "" && from && to && to >= from;

  return (
    <>
      <Link to="/bookings" className="mb-3 inline-flex items-center gap-1 text-sm text-fg-muted hover:text-fg">
        <ArrowLeft className="size-4" /> Bookings
      </Link>
      <PageHeader title="Nurse unavailable" description="Use this when a nurse falls sick or leaves. One step moves every affected booking to another nurse where possible, and cancels with a refund where not." />
      <Card className="mb-4">
        <div className="grid gap-4 p-4 sm:grid-cols-3">
          <Field label="Nurse" htmlFor="nurse">
            <Select id="nurse" value={nurseId} onChange={(e) => { setNurseId(e.target.value ? Number(e.target.value) : ""); preview.reset(); }}>
              <option value="">Choose a nurse</option>
              {nurses.data?.map((n) => (
                <option key={n.id} value={n.id}>
                  {n.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="From" htmlFor="from">
            <Input id="from" type="date" value={from} onChange={(e) => { setFrom(e.target.value); preview.reset(); }} />
          </Field>
          <Field label="To" htmlFor="to">
            <Input id="to" type="date" value={to} min={from} onChange={(e) => { setTo(e.target.value); preview.reset(); }} />
          </Field>
        </div>
        <div className="border-t border-border px-4 py-3">
          <Button disabled={!valid} loading={preview.isPending} onClick={() => preview.mutate()}>
            Show affected bookings
          </Button>
        </div>
      </Card>

      {items && (
        <Card>
          <CardHeader title={`${items.length} affected ${items.length === 1 ? "booking" : "bookings"}`} />
          {items.length === 0 ? (
            <EmptyState title="No bookings in this range" hint="Applying will still mark the nurse on leave for these days." />
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>#</Th>
                  <Th>Patient</Th>
                  <Th>When</Th>
                  <Th>What will happen</Th>
                </tr>
              </thead>
              <tbody>
                {items.map((i) => (
                  <tr key={i.booking_id}>
                    <Td>{i.booking_id}</Td>
                    <Td>{i.patient_name}</Td>
                    <Td>{formatShort(i.slot_start)}</Td>
                    <Td>{i.outcome === "reassign" ? <Badge tone="info">Move to {i.new_nurse}</Badge> : <Badge tone="danger">Cancel and refund</Badge>}</Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
          <div className="space-y-3 border-t border-border p-4">
            <Field label="Reason (shown to users whose booking is cancelled)" htmlFor="note">
              <Textarea id="note" value={note} onChange={(e) => setNote(e.target.value)} placeholder="Nurse unwell" className="min-h-14" />
            </Field>
            <p className="text-xs text-fg-muted">Cancelled bookings use the reason "nurse unavailable" in the SMS.</p>
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => preview.reset()}>
                Back
              </Button>
              <Button variant={items.some((i) => i.outcome === "cancel") ? "danger" : "primary"} loading={apply.isPending} onClick={() => apply.mutate()}>
                Apply to {items.length} {items.length === 1 ? "booking" : "bookings"}
              </Button>
            </div>
          </div>
        </Card>
      )}
    </>
  );
}
