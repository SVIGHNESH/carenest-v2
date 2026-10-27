import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { Controller, useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import { api, unwrap } from "@/api/client";
import { Badge, Button, Card, CardHeader, ErrorState, Field, Input, Loading, PageHeader, Select, Switch } from "@/components/ui";

const NOTICE = [60, 120, 180, 240, 360, 720, 1440];
const schema = z.object({
  min_notice_minutes: z.coerce.number().int().min(0),
  booking_window_days: z.coerce.number().int().min(1).max(60),
  travel_gap_hours: z.coerce.number().int().min(0).max(6),
  support_phone: z.string().trim().min(3, "Enter the support phone number"),
  bookings_paused: z.boolean(),
});
type Values = z.infer<typeof schema>;

const noticeLabel = (m: number) => (m < 60 ? `${m} minutes` : m % 60 === 0 ? `${m / 60} ${m === 60 ? "hour" : "hours"}` : `${m} minutes`);

export function SettingsPage() {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ["settings"], queryFn: () => unwrap(api.GET("/admin/settings")) });
  const form = useForm<Values>({ resolver: zodResolver(schema) as never });
  useEffect(() => {
    if (q.data) form.reset(q.data);
  }, [q.data, form]);
  const save = useMutation({
    mutationFn: (v: Values) => unwrap(api.PATCH("/admin/settings", { body: v })),
    onSuccess: (d) => {
      qc.setQueryData(["settings"], d);
      toast.success("Settings saved. The app uses them straight away.");
    },
    onError: (e) => toast.error(e.message),
  });
  if (q.isPending) return <Loading />;
  if (q.isError) return <ErrorState message={q.error.message} />;
  const options = NOTICE.includes(q.data.min_notice_minutes) ? NOTICE : [...NOTICE, q.data.min_notice_minutes].sort((a, b) => a - b);

  return (
    <>
      <PageHeader
        title="Settings"
        description="Changes apply to the user app immediately, with no app update."
        actions={
          <Button disabled={!form.formState.isDirty} loading={save.isPending} onClick={form.handleSubmit((v) => save.mutate(v))}>
            Save
          </Button>
        }
      />
      <Card className="mb-6 max-w-3xl">
        <CardHeader title="Booking rules" />
        <div className="divide-y divide-border">
          <Row title="Minimum notice time" desc="The shortest gap allowed between now and the start of a booking. Applies to every service.">
            <Select className="w-40" aria-label="Minimum notice time" {...form.register("min_notice_minutes")}>
              {options.map((m) => (
                <option key={m} value={m}>
                  {noticeLabel(m)}
                </option>
              ))}
            </Select>
          </Row>
          <Row title="Booking window" desc="How many days ahead a user is allowed to book.">
            <Select className="w-40" aria-label="Booking window" {...form.register("booking_window_days")}>
              {[1, 2, 3, 5, 7, 10, 14, 21, 30].map((d) => (
                <option key={d} value={d}>
                  {d} {d === 1 ? "day" : "days"}
                </option>
              ))}
            </Select>
          </Row>
          <Row title="Gap between visits" desc="Travel time kept free before and after a nurse's visit, in whole hours.">
            <Select className="w-40" aria-label="Gap between visits" {...form.register("travel_gap_hours")}>
              {[0, 1, 2, 3].map((d) => (
                <option key={d} value={d}>
                  {d} {d === 1 ? "hour" : "hours"}
                </option>
              ))}
            </Select>
          </Row>
          <Row title="Support phone" desc="Shown to users on a booking, so they know whom to call to change or cancel.">
            <Input className="w-40" aria-label="Support phone" {...form.register("support_phone")} />
          </Row>
          <Row title="Pause new bookings" desc="Stops all new bookings in the app at once. Existing bookings carry on as normal. Use this in an emergency.">
            <Controller control={form.control} name="bookings_paused" render={({ field }) => <Switch checked={!!field.value} onChange={(v) => field.onChange(v)} label="Pause new bookings" />} />
          </Row>
        </div>
      </Card>
      <TeamSection />
    </>
  );
}

function Row({ title, desc, children }: { title: string; desc: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-4 px-4 py-4">
      <div className="max-w-md">
        <div className="text-sm font-medium">{title}</div>
        <p className="mt-0.5 text-xs text-fg-muted">{desc}</p>
      </div>
      {children}
    </div>
  );
}

function TeamSection() {
  const qc = useQueryClient();
  const team = useQuery({ queryKey: ["team"], queryFn: () => unwrap(api.GET("/admin/team")) });
  const me = useQuery({ queryKey: ["me"], queryFn: () => unwrap(api.GET("/admin/me")) });
  const form = useForm({ resolver: zodResolver(z.object({ name: z.string().trim().min(1, "Enter a name"), email: z.string().email("Enter a valid email") })), defaultValues: { name: "", email: "" } });
  const add = useMutation({
    mutationFn: (v: { name: string; email: string }) => unwrap(api.POST("/admin/team", { body: v })),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["team"] });
      form.reset();
      toast.success("Invite sent. They set a password from the email link.");
    },
    onError: (e) => toast.error(e.message),
  });
  const toggle = useMutation({
    mutationFn: ({ id, active }: { id: number; active: boolean }) =>
      unwrap(active ? api.POST("/admin/team/{admin_id}/deactivate", { params: { path: { admin_id: id } } }) : api.POST("/admin/team/{admin_id}/activate", { params: { path: { admin_id: id } } })),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["team"] }),
    onError: (e) => toast.error(e.message),
  });
  const { errors } = form.formState;
  return (
    <Card className="max-w-3xl">
      <CardHeader title="Team" />
      <p className="px-4 pt-3 text-xs text-fg-muted">All admins have the same rights. Every action is recorded in the booking history.</p>
      {team.isPending ? (
        <Loading />
      ) : (
        <ul className="divide-y divide-border">
          {team.data?.map((a) => (
            <li key={a.id} className="flex items-center gap-3 px-4 py-3">
              <div className="min-w-0 flex-1">
                <div className="text-sm font-medium">{a.name || a.email}</div>
                <div className="text-xs text-fg-muted">{a.email}</div>
              </div>
              {a.is_active ? <Badge tone="success">Active</Badge> : <Badge>Deactivated</Badge>}
              {a.id !== me.data?.id && (
                <Button size="sm" variant="ghost" onClick={() => toggle.mutate({ id: a.id, active: a.is_active })}>
                  {a.is_active ? "Deactivate" : "Reactivate"}
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}
      <form onSubmit={form.handleSubmit((v) => add.mutate(v))} noValidate className="grid gap-3 border-t border-border bg-surface-sunken p-4 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
        <Field label="Name" htmlFor="t-name" error={errors.name?.message}>
          <Input id="t-name" {...form.register("name")} />
        </Field>
        <Field label="Email" htmlFor="t-email" error={errors.email?.message}>
          <Input id="t-email" type="email" {...form.register("email")} />
        </Field>
        <Button type="submit" loading={add.isPending}>
          Invite admin
        </Button>
      </form>
    </Card>
  );
}
