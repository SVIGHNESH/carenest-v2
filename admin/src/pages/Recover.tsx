import { zodResolver } from "@hookform/resolvers/zod";
import { Link, useNavigate, useSearch } from "@tanstack/react-router";
import { useMutation } from "@tanstack/react-query";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { api, unwrap } from "@/api/client";
import { AuthLayout } from "@/components/AuthLayout";
import { Button, Field, Input } from "@/components/ui";

export function ForgotPasswordPage() {
  const [sent, setSent] = useState(false);
  const form = useForm({ resolver: zodResolver(z.object({ email: z.string().email("Enter a valid email") })), defaultValues: { email: "" } });
  const m = useMutation({
    mutationFn: (v: { email: string }) => unwrap(api.POST("/admin/auth/forgot-password", { body: v })),
    onSuccess: () => setSent(true),
  });
  return (
    <AuthLayout title="Forgot password" subtitle={sent ? undefined : "We email you a reset link."}>
      {sent ? (
        <p className="text-sm text-fg-secondary">If that email belongs to an admin, a reset link is on its way. It works for one hour.</p>
      ) : (
        <form onSubmit={form.handleSubmit((v) => m.mutate(v))} className="space-y-4" noValidate>
          <Field label="Email" htmlFor="email" error={form.formState.errors.email?.message}>
            <Input id="email" type="email" autoFocus {...form.register("email")} />
          </Field>
          {m.error && <p role="alert" className="text-sm text-danger">{m.error.message}</p>}
          <Button type="submit" className="w-full" size="lg" loading={m.isPending}>
            Send reset link
          </Button>
        </form>
      )}
      <div className="mt-4 text-center">
        <Link to="/login" className="text-sm text-accent-text hover:underline">
          Back to login
        </Link>
      </div>
    </AuthLayout>
  );
}

const schema = z
  .object({ password: z.string().min(10, "Use at least 10 characters"), confirm: z.string() })
  .refine((v) => v.password === v.confirm, { path: ["confirm"], message: "Passwords do not match" });

export function ResetPasswordPage() {
  const { token } = useSearch({ from: "/reset-password" });
  const navigate = useNavigate();
  const form = useForm({ resolver: zodResolver(schema), defaultValues: { password: "", confirm: "" } });
  const m = useMutation({
    mutationFn: (v: { password: string }) => unwrap(api.POST("/admin/auth/reset-password", { body: { token: token ?? "", password: v.password } })),
    onSuccess: () => navigate({ to: "/login" }),
  });
  return (
    <AuthLayout title="Set new password">
      <form onSubmit={form.handleSubmit((v) => m.mutate(v))} className="space-y-4" noValidate>
        <Field label="New password" htmlFor="password" error={form.formState.errors.password?.message}>
          <Input id="password" type="password" autoComplete="new-password" autoFocus {...form.register("password")} />
        </Field>
        <Field label="Confirm password" htmlFor="confirm" error={form.formState.errors.confirm?.message}>
          <Input id="confirm" type="password" autoComplete="new-password" {...form.register("confirm")} />
        </Field>
        {m.error && <p role="alert" className="text-sm text-danger">{m.error.message}</p>}
        <Button type="submit" className="w-full" size="lg" loading={m.isPending}>
          Save password
        </Button>
      </form>
    </AuthLayout>
  );
}
