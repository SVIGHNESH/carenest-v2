import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useParams } from "@tanstack/react-router";
import { ArrowLeft, ChevronLeft, ChevronRight } from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { api, unwrap } from "@/api/client";
import { Button, Card, CardHeader, Dialog, ErrorState, Field, Loading, PageHeader, Select, Switch } from "@/components/ui";
import { formatShort, hourLabel, WEEKDAYS } from "@/lib/format";
import { cn } from "@/lib/utils";

type Row = { on: boolean; start: number; end: number };
const defaultRows = (): Row[] => WEEKDAYS.map((_, i) => ({ on: i < 6, start: 8, end: 20 }));
const HOURS = Array.from({ length: 24 }, (_, i) => i);

const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

export function AvailabilityPage() {
  const { id } = useParams({ from: "/app/nurses/$id/availability" });
  const nurseId = Number(id);
  const nurse = useQuery({ queryKey: ["nurse", nurseId], queryFn: () => unwrap(api.GET("/admin/nurses/{nurse_id}", { params: { path: { nurse_id: nurseId } } })) });
  if (nurse.isPending) return <Loading />;
  if (nurse.isError) return <ErrorState message={nurse.error.message} />;
  return <Editor key={JSON.stringify(nurse.data.weekly_hours)} nurse={nurse.data} nurseId={nurseId} />;
}

function rowsFrom(hours: { weekday: number; start_hour: number; end_hour: number }[]): Row[] {
  if (hours.length === 0) return defaultRows();
  const base: Row[] = WEEKDAYS.map(() => ({ on: false, start: 8, end: 20 }));
  for (const h of hours) base[h.weekday] = { on: true, start: h.start_hour, end: h.end_hour };
  return base;
}

function Editor({ nurse, nurseId }: { nurse: { name: string; weekly_hours: { weekday: number; start_hour: number; end_hour: number }[] }; nurseId: number }) {
  const qc = useQueryClient();
  const [rows, setRows] = useState<Row[]>(() => rowsFrom(nurse.weekly_hours));
  const [dirty, setDirty] = useState(nurse.weekly_hours.length === 0);

  const save = useMutation({
    mutationFn: () =>
      unwrap(
        api.PUT("/admin/nurses/{nurse_id}/weekly-hours", {
          params: { path: { nurse_id: nurseId } },
          body: rows.flatMap((r, weekday) => (r.on ? [{ weekday, start_hour: r.start, end_hour: r.end }] : [])),
        }),
      ),
    onSuccess: (n) => {
      qc.setQueryData(["nurse", nurseId], n);
      qc.invalidateQueries({ queryKey: ["nurses"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      setDirty(false);
      toast.success("Working hours saved");
    },
    onError: (e) => toast.error(e.message),
  });

  const patch = (i: number, p: Partial<Row>) => {
    setRows((r) => r.map((x, j) => (j === i ? { ...x, ...p } : x)));
    setDirty(true);
  };
  const invalid = rows.some((r) => r.on && r.end <= r.start);

  return (
    <>
      <Link to="/nurses" className="mb-3 inline-flex items-center gap-1 text-sm text-fg-muted hover:text-fg">
        <ArrowLeft className="size-4" /> Nurses
      </Link>
      <PageHeader
        title={`Availability for ${nurse.name}`}
        description="Weekly hours are the normal pattern. The calendar is for leave and one-off changes. A nurse with no working hours is never bookable."
        actions={
          <Button disabled={!dirty || invalid} loading={save.isPending} onClick={() => save.mutate()}>
            Save
          </Button>
        }
      />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,26rem)_1fr]">
        <Card>
          <CardHeader title="Weekly working hours" />
          <ul className="divide-y divide-border">
            {rows.map((r, i) => (
              <li key={i} className="flex items-center gap-3 px-4 py-2.5">
                <Switch checked={r.on} onChange={(v) => patch(i, { on: v })} label={`${WEEKDAYS[i]} working`} />
                <span className="w-10 text-sm font-medium">{WEEKDAYS[i]}</span>
                {r.on ? (
                  <span className="flex items-center gap-1.5 text-sm">
                    <Select className="w-28" aria-label={`${WEEKDAYS[i]} start`} value={r.start} onChange={(e) => patch(i, { start: Number(e.target.value) })}>
                      {HOURS.map((h) => (
                        <option key={h} value={h}>
                          {hourLabel(h)}
                        </option>
                      ))}
                    </Select>
                    to
                    <Select className="w-28" aria-label={`${WEEKDAYS[i]} end`} value={r.end} onChange={(e) => patch(i, { end: Number(e.target.value) })} aria-invalid={r.end <= r.start}>
                      {HOURS.slice(1).concat(24).map((h) => (
                        <option key={h} value={h}>
                          {hourLabel(h)}
                        </option>
                      ))}
                    </Select>
                  </span>
                ) : (
                  <span className="text-sm text-fg-muted">Day off</span>
                )}
              </li>
            ))}
          </ul>
          {invalid && (
            <p role="alert" className="px-4 pb-3 text-xs text-danger">
              End time must be after start time.
            </p>
          )}
        </Card>
        <MonthCalendar nurseId={nurseId} />
      </div>
    </>
  );
}

function MonthCalendar({ nurseId }: { nurseId: number }) {
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [selected, setSelected] = useState<string | null>(null);
  const key = `${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, "0")}`;
  const overrides = useQuery({ queryKey: ["overrides", nurseId, key], queryFn: () => unwrap(api.GET("/admin/nurses/{nurse_id}/overrides", { params: { path: { nurse_id: nurseId }, query: { month: key } } })) });
  const bookings = useQuery({ queryKey: ["bookings", "nurse", nurseId], queryFn: () => unwrap(api.GET("/admin/bookings", { params: { query: { nurse_id: nurseId, limit: 500 } } })) });

  const byDay = useMemo(() => new Map(overrides.data?.map((o) => [o.day, o]) ?? []), [overrides.data]);
  const booked = useMemo(() => {
    const m = new Map<string, number>();
    for (const b of bookings.data ?? []) if (b.status === "confirmed" || b.status === "in_progress") m.set(b.slot_start.slice(0, 10), (m.get(b.slot_start.slice(0, 10)) ?? 0) + 1);
    return m;
  }, [bookings.data]);

  const first = new Date(month);
  const lead = (first.getDay() + 6) % 7;
  const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const cells = [...Array(lead).fill(null), ...Array.from({ length: days }, (_, i) => i + 1)];

  return (
    <Card>
      <CardHeader
        title={month.toLocaleString("en-IN", { month: "long", year: "numeric" })}
        action={
          <div className="flex gap-1">
            <Button size="sm" variant="outline" aria-label="Previous month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}>
              <ChevronLeft className="size-4" />
            </Button>
            <Button size="sm" variant="outline" aria-label="Next month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}>
              <ChevronRight className="size-4" />
            </Button>
          </div>
        }
      />
      <div className="p-4">
        <div className="grid grid-cols-7 gap-1 text-center text-xs text-fg-muted">
          {WEEKDAYS.map((d) => (
            <div key={d} className="py-1">
              {d}
            </div>
          ))}
          {cells.map((c, i) => {
            if (c === null) return <div key={`b${i}`} />;
            const day = iso(new Date(month.getFullYear(), month.getMonth(), c));
            const o = byDay.get(day);
            const n = booked.get(day) ?? 0;
            return (
              <button
                key={day}
                onClick={() => setSelected(day)}
                aria-label={`${day}${o ? (o.is_leave ? ", leave" : ", different hours") : ""}${n ? `, ${n} bookings` : ""}`}
                className={cn(
                  "relative h-12 rounded-md border text-sm text-fg hover:bg-surface-hover",
                  o?.is_leave ? "border-danger/40 bg-danger-soft" : o ? "border-warning/50 bg-warning-soft" : "border-border",
                )}
              >
                {c}
                {n > 0 && <span className="absolute right-1 bottom-1 size-1.5 rounded-full bg-info" aria-hidden />}
              </button>
            );
          })}
        </div>
        <div className="mt-3 flex flex-wrap gap-4 text-xs text-fg-muted">
          <Legend className="bg-danger-soft border-danger/40" label="Leave" />
          <Legend className="bg-warning-soft border-warning/50" label="Different hours that day" />
          <span className="inline-flex items-center gap-1.5">
            <span className="size-1.5 rounded-full bg-info" /> Has bookings
          </span>
        </div>
        <p className="mt-3 text-xs text-fg-muted">Click a day to mark leave or change that day's hours.</p>
      </div>
      {selected && (
        <DayDialog
          nurseId={nurseId}
          day={selected}
          existing={byDay.get(selected)}
          bookingsThatDay={(bookings.data ?? []).filter((b) => b.slot_start.startsWith(selected) && (b.status === "confirmed" || b.status === "in_progress"))}
          onClose={() => setSelected(null)}
        />
      )}
    </Card>
  );
}

const Legend = ({ className, label }: { className: string; label: string }) => (
  <span className="inline-flex items-center gap-1.5">
    <span className={cn("size-3 rounded-sm border", className)} /> {label}
  </span>
);

function DayDialog({ nurseId, day, existing, bookingsThatDay, onClose }: { nurseId: number; day: string; existing?: { is_leave: boolean; start_hour?: number | null; end_hour?: number | null }; bookingsThatDay: { id: number; slot_start: string; patient_name: string }[]; onClose: () => void }) {
  const qc = useQueryClient();
  const [mode, setMode] = useState<"leave" | "hours">(existing && !existing.is_leave ? "hours" : "leave");
  const [start, setStart] = useState(existing?.start_hour ?? 9);
  const [end, setEnd] = useState(existing?.end_hour ?? 17);
  const blocked = mode === "leave" && bookingsThatDay.length > 0;
  const done = () => {
    qc.invalidateQueries({ queryKey: ["overrides", nurseId] });
    qc.invalidateQueries({ queryKey: ["dashboard"] });
    onClose();
  };
  const save = useMutation({
    mutationFn: () => unwrap(api.PUT("/admin/nurses/{nurse_id}/overrides/{day}", { params: { path: { nurse_id: nurseId, day } }, body: mode === "leave" ? { is_leave: true } : { is_leave: false, start_hour: start, end_hour: end } })),
    onSuccess: () => {
      toast.success("Saved");
      done();
    },
    onError: (e) => toast.error(e.message),
  });
  const remove = useMutation({
    mutationFn: () => unwrap(api.DELETE("/admin/nurses/{nurse_id}/overrides/{day}", { params: { path: { nurse_id: nurseId, day } } })),
    onSuccess: done,
    onError: (e) => toast.error(e.message),
  });
  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={new Date(day + "T00:00").toLocaleDateString("en-IN", { weekday: "long", day: "numeric", month: "long" })}
      footer={
        <>
          {existing && (
            <Button variant="ghost" className="mr-auto" loading={remove.isPending} onClick={() => remove.mutate()}>
              Back to normal hours
            </Button>
          )}
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
          <Button disabled={blocked || (mode === "hours" && end <= start)} loading={save.isPending} onClick={() => save.mutate()}>
            Save
          </Button>
        </>
      }
    >
      <div className="mb-4 flex gap-2" role="radiogroup" aria-label="Day type">
        {(["leave", "hours"] as const).map((m) => (
          <label key={m} className="flex flex-1 cursor-pointer items-center gap-2 rounded-md border border-border-strong px-3 py-2 text-sm has-[:checked]:border-accent-brand has-[:checked]:bg-accent-soft">
            <input type="radio" checked={mode === m} onChange={() => setMode(m)} className="accent-[var(--accent)]" />
            {m === "leave" ? "On leave" : "Different hours"}
          </label>
        ))}
      </div>
      {mode === "hours" && (
        <Field label="Working hours that day">
          <div className="flex items-center gap-2 text-sm">
            <Select aria-label="Start" value={start} onChange={(e) => setStart(Number(e.target.value))}>
              {HOURS.map((h) => (
                <option key={h} value={h}>
                  {hourLabel(h)}
                </option>
              ))}
            </Select>
            to
            <Select aria-label="End" value={end} onChange={(e) => setEnd(Number(e.target.value))}>
              {HOURS.slice(1).concat(24).map((h) => (
                <option key={h} value={h}>
                  {hourLabel(h)}
                </option>
              ))}
            </Select>
          </div>
        </Field>
      )}
      {bookingsThatDay.length > 0 && (
        <div role="alert" className="mt-4 rounded-md border border-warning/50 bg-warning-soft p-3 text-sm">
          <p className="font-medium">This day already has bookings</p>
          <ul className="mt-1 list-disc pl-5 text-fg-secondary">
            {bookingsThatDay.map((b) => (
              <li key={b.id}>
                #{b.id}, {b.patient_name}, {formatShort(b.slot_start)}
              </li>
            ))}
          </ul>
          {mode === "leave" ? (
            <p className="mt-2">
              Move or cancel them first with{" "}
              <Link to="/bookings/nurse-unavailable" className="font-medium text-accent-text underline">
                Nurse unavailable
              </Link>
              , which also marks the leave.
            </p>
          ) : (
            <p className="mt-2 text-fg-secondary">Check that the new hours still cover these visits.</p>
          )}
        </div>
      )}
    </Dialog>
  );
}
