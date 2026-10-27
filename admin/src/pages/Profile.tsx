import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import { api, unwrap } from "@/api/client";
import { Button, Card, CardHeader, Field, Input, Loading, PageHeader } from "@/components/ui";

const pw = z
  .object({ current_password: z.string().min(1, "Enter your current password"), new_password: z.string().min(10, "Use at least 10 characters") })
  .refine((v) => v.new_password !== v.current_password, { path: ["new_password"], message: "Choose a different password" });

export function ProfilePage() {
  const qc = useQueryClient();
  const me = useQuery({ queryKey: ["me"], queryFn: () => unwrap(api.GET("/admin/me")) });
  const nameForm = useForm({ resolver: zodResolver(z.object({ name: z.string().trim().min(1, "Enter your name") })), defaultValues: { name: "" } });
  const pwForm = useForm({ resolver: zodResolver(pw), defaultValues: { current_password: "", new_password: "" } });
  useEffect(() => {
    if (me.data) nameForm.reset({ name: me.data.name });
  }, [me.data, nameForm]);
  const saveName = useMutation({
    mutationFn: (v: { name: string }) => unwrap(api.PATCH("/admin/me", { body: v })),
    onSuccess: (d) => {
      qc.setQueryData(["me"], d);
      toast.success("Profile saved");
    },
    onError: (e) => toast.error(e.message),
  });
  const savePw = useMutation({
    mutationFn: (v: z.infer<typeof pw>) => unwrap(api.POST("/admin/me/password", { body: v })),
    onSuccess: () => {
      pwForm.reset();
      toast.success("Password changed");
    },
    onError: (e) => toast.error(e.message),
  });
  if (me.isPending) return <Loading />;
  return (
    <>
      <PageHeader title="Profile" description="Your own account details and password." />
      <div className="grid max-w-3xl gap-4">
        <Card>
          <CardHeader title="Account" />
          <form onSubmit={nameForm.handleSubmit((v) => saveName.mutate(v))} className="grid gap-4 p-4 sm:grid-cols-2" noValidate>
            <Field label="Full name" htmlFor="p-name" error={nameForm.formState.errors.name?.message}>
              <Input id="p-name" {...nameForm.register("name")} />
            </Field>
            <Field label="Email" htmlFor="p-email" hint="Contact another admin to change this.">
              <Input id="p-email" value={me.data?.email ?? ""} disabled readOnly />
            </Field>
            <div>
              <Button type="submit" loading={saveName.isPending}>
                Save
              </Button>
            </div>
          </form>
        </Card>
        <Card>
          <CardHeader title="Change password" />
          <form onSubmit={pwForm.handleSubmit((v) => savePw.mutate(v))} className="grid gap-4 p-4 sm:grid-cols-2" noValidate>
            <Field label="Current password" htmlFor="cp" error={pwForm.formState.errors.current_password?.message}>
              <Input id="cp" type="password" autoComplete="current-password" {...pwForm.register("current_password")} />
            </Field>
            <Field label="New password" htmlFor="np" error={pwForm.formState.errors.new_password?.message}>
              <Input id="np" type="password" autoComplete="new-password" {...pwForm.register("new_password")} />
            </Field>
            <div>
              <Button type="submit" loading={savePw.isPending}>
                Change password
              </Button>
            </div>
          </form>
        </Card>
      </div>
    </>
  );
}
