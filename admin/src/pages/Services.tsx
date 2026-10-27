import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Plus } from "lucide-react";
import { useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import { api, type Schemas, unwrap } from "@/api/client";
import { Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, Loading, PageHeader, Switch, Table, Td, Textarea, Th } from "@/components/ui";
import { rupees } from "@/lib/format";

type Service = Schemas["AdminServiceOut"];
const schema = z.object({
  name: z.string().trim().min(1, "Enter a service name"),
  description: z.string(),
  base_price: z.coerce.number().int().min(1, "Enter a price").max(100000),
  active: z.boolean(),
});
type Values = z.infer<typeof schema>;

export function ServicesPage() {
  const q = useQuery({ queryKey: ["services"], queryFn: () => unwrap(api.GET("/admin/services")) });
  const [editing, setEditing] = useState<Service | "new" | null>(null);
  return (
    <>
      <PageHeader
        title="Services"
        description="The services users can book, and their hourly price. Price is per hour, tax included. Existing bookings keep the price they were made at."
        actions={
          <Button onClick={() => setEditing("new")}>
            <Plus className="size-4" /> Add service
          </Button>
        }
      />
      <Card>
        {q.isPending ? (
          <Loading />
        ) : q.isError ? (
          <ErrorState message={q.error.message} onRetry={() => q.refetch()} />
        ) : q.data.length === 0 ? (
          <EmptyState title="No services yet" />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>Service</Th>
                <Th>Price per hour</Th>
                <Th>Nurses</Th>
                <Th>Status</Th>
                <Th>
                  <span className="sr-only">Actions</span>
                </Th>
              </tr>
            </thead>
            <tbody>
              {q.data.map((s) => (
                <tr key={s.id} className="hover:bg-surface-hover">
                  <Td className="font-medium">{s.name}</Td>
                  <Td>{rupees(s.base_price)}</Td>
                  <Td>
                    {s.nurse_count === 0 ? <Badge tone="warning">No nurse can do this</Badge> : s.nurse_count}
                  </Td>
                  <Td>{s.active ? <Badge tone="success">Active</Badge> : <Badge>Hidden</Badge>}</Td>
                  <Td className="text-right">
                    <Button size="sm" variant="ghost" onClick={() => setEditing(s)}>
                      Edit
                    </Button>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
      {editing && <ServiceForm service={editing === "new" ? null : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function ServiceForm({ service, onClose }: { service: Service | null; onClose: () => void }) {
  const qc = useQueryClient();
  const form = useForm<Values>({
    resolver: zodResolver(schema) as never,
    defaultValues: { name: service?.name ?? "", description: service?.description ?? "", base_price: service?.base_price ?? 400, active: service?.active ?? true },
  });
  const { errors } = form.formState;
  const save = useMutation({
    mutationFn: (v: Values) =>
      service ? unwrap(api.PATCH("/admin/services/{service_id}", { params: { path: { service_id: service.id } }, body: v })) : unwrap(api.POST("/admin/services", { body: v })),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["services"] });
      toast.success("Service saved");
      onClose();
    },
    onError: (e) => toast.error(e.message),
  });
  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={service ? `Edit ${service.name}` : "Add service"}
      footer={
        <>
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
        <Field label="Service name" htmlFor="s-name" error={errors.name?.message}>
          <Input id="s-name" {...form.register("name")} aria-invalid={!!errors.name} />
        </Field>
        <Field label="Description" htmlFor="s-desc">
          <Textarea id="s-desc" {...form.register("description")} />
        </Field>
        <Field label="Price per hour (Rs)" htmlFor="s-price" error={errors.base_price?.message}>
          <Input id="s-price" type="number" min={1} className="w-32" {...form.register("base_price")} aria-invalid={!!errors.base_price} />
        </Field>
        <div className="flex items-center gap-3">
          <Controller control={form.control} name="active" render={({ field }) => <Switch checked={field.value} onChange={field.onChange} label="Show in app" />} />
          <span className="text-sm">Show in app</span>
        </div>
      </form>
    </Dialog>
  );
}
