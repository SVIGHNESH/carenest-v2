import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import { Plus } from "lucide-react";
import { useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import { api, type Schemas, unwrap } from "@/api/client";
import { Badge, Button, Card, EmptyState, ErrorState, Field, Input, Loading, PageHeader, Table, Td, Textarea, Th, Dialog } from "@/components/ui";
import { hoursSummary } from "@/lib/format";

type Nurse = Schemas["NurseOut"];

const schema = z.object({
  name: z.string().trim().min(1, "Enter the nurse's name"),
  gender: z.enum(["female", "male"], { message: "Choose a gender" }),
  phone: z.string().trim().min(10, "Enter a 10-digit mobile number"),
  email: z.string().trim().email("Enter a valid email").or(z.literal("")),
  experience_years: z.coerce.number().int().min(0).max(60),
  notes: z.string().optional(),
  service_ids: z.array(z.number()).min(1, "Tick at least one service"),
});
type FormValues = z.infer<typeof schema>;

export function NursesPage() {
  const nurses = useQuery({ queryKey: ["nurses"], queryFn: () => unwrap(api.GET("/admin/nurses")) });
  const services = useQuery({ queryKey: ["services"], queryFn: () => unwrap(api.GET("/admin/services")) });
  const [editing, setEditing] = useState<Nurse | "new" | null>(null);
  const svcName = (id: number) => services.data?.find((s) => s.id === id)?.name ?? `#${id}`;

  return (
    <>
      <PageHeader
        title="Nurses"
        description="A nurse is offered to users only when gender, at least one service and working hours are all filled in."
        actions={
          <Button onClick={() => setEditing("new")}>
            <Plus className="size-4" /> Add nurse
          </Button>
        }
      />
      <Card>
        {nurses.isPending ? (
          <Loading />
        ) : nurses.isError ? (
          <ErrorState message={nurses.error.message} onRetry={() => nurses.refetch()} />
        ) : nurses.data.length === 0 ? (
          <EmptyState title="No nurses yet" hint="Add a nurse, tick the services they can do, then set their working hours." />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>Name</Th>
                <Th>Gender</Th>
                <Th>Phone</Th>
                <Th>Working hours</Th>
                <Th>Status</Th>
                <Th>
                  <span className="sr-only">Actions</span>
                </Th>
              </tr>
            </thead>
            <tbody>
              {nurses.data.map((n) => (
                <tr key={n.id} className="hover:bg-surface-hover">
                  <Td>
                    <div className="font-medium">{n.name}</div>
                    <div className="max-w-56 truncate text-xs text-fg-muted">{n.service_ids.map(svcName).join(", ")}</div>
                  </Td>
                  <Td className="capitalize">{n.gender}</Td>
                  <Td>{n.phone}</Td>
                  <Td>{hoursSummary(n.weekly_hours)}</Td>
                  <Td>
                    {!n.is_active ? <Badge>Inactive</Badge> : n.setup_issues.length ? <Badge tone="warning">Not bookable</Badge> : <Badge tone="success">Bookable</Badge>}
                    {n.setup_issues.map((i) => (
                      <div key={i} className="mt-0.5 text-xs text-fg-muted">
                        {i}
                      </div>
                    ))}
                  </Td>
                  <Td className="text-right whitespace-nowrap">
                    <Link to="/nurses/$id/availability" params={{ id: String(n.id) }}>
                      <Button size="sm" variant="outline">
                        Availability
                      </Button>
                    </Link>{" "}
                    <Button size="sm" variant="ghost" onClick={() => setEditing(n)}>
                      Edit
                    </Button>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
      {editing && <NurseForm nurse={editing === "new" ? null : editing} services={services.data ?? []} onClose={() => setEditing(null)} />}
    </>
  );
}

function NurseForm({ nurse, services, onClose }: { nurse: Nurse | null; services: Schemas["AdminServiceOut"][]; onClose: () => void }) {
  const qc = useQueryClient();
  const form = useForm<FormValues>({
    resolver: zodResolver(schema) as never,
    defaultValues: {
      name: nurse?.name ?? "",
      gender: (nurse?.gender as "female" | "male") ?? undefined,
      phone: nurse?.phone ?? "",
      email: nurse?.email ?? "",
      experience_years: nurse?.experience_years ?? 0,
      notes: nurse?.notes ?? "",
      service_ids: nurse?.service_ids ?? [],
    },
  });
  const { errors } = form.formState;
  const save = useMutation({
    mutationFn: async (v: FormValues) => {
      const body = { ...v, email: v.email || undefined, notes: v.notes || undefined };
      return nurse
        ? unwrap(api.PATCH("/admin/nurses/{nurse_id}", { params: { path: { nurse_id: nurse.id } }, body: { ...body, is_active: nurse.is_active } }))
        : unwrap(api.POST("/admin/nurses", { body: { ...body, is_active: true } }));
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["nurses"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      toast.success(nurse ? "Nurse updated" : "Nurse added. Now set their working hours.");
      onClose();
    },
    onError: (e) => toast.error(e.message),
  });
  const toggleActive = useMutation({
    mutationFn: () => unwrap(api.PATCH("/admin/nurses/{nurse_id}", { params: { path: { nurse_id: nurse!.id } }, body: { is_active: !nurse!.is_active } })),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["nurses"] });
      onClose();
    },
    onError: (e) => toast.error(e.message),
  });

  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={nurse ? `Edit ${nurse.name}` : "Add nurse"}
      description="The nurse gets no login. Phone and email are only where visit details are sent."
      footer={
        <>
          {nurse && (
            <Button variant={nurse.is_active ? "danger-outline" : "outline"} className="mr-auto" loading={toggleActive.isPending} onClick={() => toggleActive.mutate()}>
              {nurse.is_active ? "Deactivate" : "Reactivate"}
            </Button>
          )}
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
          <Button loading={save.isPending} onClick={form.handleSubmit((v) => save.mutate(v))}>
            Save
          </Button>
        </>
      }
    >
      <form className="space-y-4" noValidate onSubmit={form.handleSubmit((v) => save.mutate(v))}>
        <Field label="Full name" htmlFor="n-name" error={errors.name?.message}>
          <Input id="n-name" {...form.register("name")} aria-invalid={!!errors.name} />
        </Field>
        <Field label="Gender (required)" error={errors.gender?.message}>
          <div className="flex gap-2" role="radiogroup" aria-label="Gender">
            {(["female", "male"] as const).map((g) => (
              <label key={g} className="flex flex-1 cursor-pointer items-center gap-2 rounded-md border border-border-strong px-3 py-2 text-sm capitalize has-[:checked]:border-accent-brand has-[:checked]:bg-accent-soft">
                <input type="radio" value={g} {...form.register("gender")} className="accent-[var(--accent)]" /> {g}
              </label>
            ))}
          </div>
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Phone (visit details are sent here by SMS)" htmlFor="n-phone" error={errors.phone?.message}>
            <Input id="n-phone" inputMode="tel" {...form.register("phone")} aria-invalid={!!errors.phone} />
          </Field>
          <Field label="Email" htmlFor="n-email" error={errors.email?.message}>
            <Input id="n-email" type="email" {...form.register("email")} aria-invalid={!!errors.email} />
          </Field>
        </div>
        <Field label="Years of experience" htmlFor="n-exp">
          <Input id="n-exp" type="number" min={0} className="w-28" {...form.register("experience_years")} />
        </Field>
        <Field label="Services this nurse can do (at least one)" error={errors.service_ids?.message as string | undefined}>
          <Controller
            control={form.control}
            name="service_ids"
            render={({ field }) => (
              <div className="grid gap-1.5 sm:grid-cols-2">
                {services.map((s) => (
                  <label key={s.id} className="flex cursor-pointer items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={field.value.includes(s.id)}
                      onChange={(e) => field.onChange(e.target.checked ? [...field.value, s.id] : field.value.filter((x) => x !== s.id))}
                      className="size-4 accent-[var(--accent)]"
                    />
                    {s.name}
                    {!s.active && <span className="text-xs text-fg-muted">(hidden)</span>}
                  </label>
                ))}
              </div>
            )}
          />
        </Field>
        <Field label="Notes (admin only)" htmlFor="n-notes">
          <Textarea id="n-notes" {...form.register("notes")} />
        </Field>
      </form>
    </Dialog>
  );
}
