import { zodResolver } from "@hookform/resolvers/zod";
import { Link, useNavigate } from "@tanstack/react-router";
import { useMutation } from "@tanstack/react-query";
import { QRCodeSVG } from "qrcode.react";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { api, errorMessage, tokenStore, unwrap } from "@/api/client";
import { AuthLayout } from "@/components/AuthLayout";
import { Button, Field, Input } from "@/components/ui";

const credentials = z.object({ email: z.string().email("Enter a valid email"), password: z.string().min(1, "Enter your password") });
const codeSchema = z.object({ code: z.string().min(6, "Enter the 6-digit code") });

type Stage =
  | { kind: "credentials" }
  | { kind: "mfa"; ticket: string }
  | { kind: "setup"; ticket: string; secret: string; uri: string }
  | { kind: "backup"; token: string; codes: string[] };

export function LoginPage() {
  const [stage, setStage] = useState<Stage>({ kind: "credentials" });
  const navigate = useNavigate();
  const finish = (token: string) => {
    tokenStore.set(token);
    navigate({ to: "/" });
  };

  if (stage.kind === "credentials") return <Credentials onNext={setStage} />;
  if (stage.kind === "mfa") return <Mfa ticket={stage.ticket} onDone={finish} />;
  if (stage.kind === "setup") return <Setup stage={stage} onDone={(token, codes) => setStage({ kind: "backup", token, codes })} />;
  return (
    <AuthLayout title="Save your backup codes" subtitle="Each code works once if you lose your phone. Keep them somewhere safe.">
      <ul className="grid grid-cols-2 gap-2 rounded-md bg-surface-sunken p-3 font-mono text-sm" aria-label="Backup codes">
        {stage.codes.map((c) => (
          <li key={c}>{c}</li>
        ))}
      </ul>
      <Button className="mt-4 w-full" onClick={() => finish(stage.token)}>
        I have saved them
      </Button>
    </AuthLayout>
  );
}

function Credentials({ onNext }: { onNext: (s: Stage) => void }) {
  const form = useForm({ resolver: zodResolver(credentials), defaultValues: { email: "", password: "" } });
  const m = useMutation({
    mutationFn: async (v: z.infer<typeof credentials>) => {
      const r = await unwrap(api.POST("/admin/auth/login", { body: v }), { silent401: true });
      if (r.step === "mfa") return { kind: "mfa", ticket: r.ticket! } as Stage;
      const s = await unwrap(api.POST("/admin/auth/totp/setup", { body: { ticket: r.ticket! } }));
      return { kind: "setup", ticket: r.ticket!, secret: s.secret, uri: s.otpauth_uri } as Stage;
    },
    onSuccess: onNext,
  });
  return (
    <AuthLayout title="Sign in">
      <form onSubmit={form.handleSubmit((v) => m.mutate(v))} className="space-y-4" noValidate>
        <Field label="Email" htmlFor="email" error={form.formState.errors.email?.message}>
          <Input id="email" type="email" autoComplete="username" autoFocus {...form.register("email")} aria-invalid={!!form.formState.errors.email} />
        </Field>
        <Field label="Password" htmlFor="password" error={form.formState.errors.password?.message}>
          <Input id="password" type="password" autoComplete="current-password" {...form.register("password")} aria-invalid={!!form.formState.errors.password} />
        </Field>
        {m.error && (
          <p role="alert" className="text-sm text-danger">
            {m.error.message}
          </p>
        )}
        <Button type="submit" className="w-full" size="lg" loading={m.isPending}>
          Sign in
        </Button>
        <div className="text-center">
          <Link to="/forgot-password" className="text-sm text-accent-text hover:underline">
            Forgot password?
          </Link>
        </div>
      </form>
    </AuthLayout>
  );
}

function CodeForm({ label, hint, submit, loading, error }: { label: string; hint?: string; submit: (code: string) => void; loading: boolean; error?: string }) {
  const form = useForm({ resolver: zodResolver(codeSchema), defaultValues: { code: "" } });
  return (
    <form onSubmit={form.handleSubmit((v) => submit(v.code))} className="space-y-4" noValidate>
      <Field label={label} hint={hint} htmlFor="code" error={form.formState.errors.code?.message}>
        <Input id="code" inputMode="numeric" autoComplete="one-time-code" autoFocus className="text-center font-mono text-lg tracking-widest" {...form.register("code")} />
      </Field>
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}
      <Button type="submit" className="w-full" size="lg" loading={loading}>
        Verify
      </Button>
    </form>
  );
}

function Mfa({ ticket, onDone }: { ticket: string; onDone: (token: string) => void }) {
  const m = useMutation({
    mutationFn: (code: string) => unwrap(api.POST("/admin/auth/mfa", { body: { ticket, code } }), { silent401: true }),
    onSuccess: (r) => onDone(r.access_token),
  });
  return (
    <AuthLayout title="Two-step check" subtitle="Open your authenticator app and enter the 6-digit code, or use a backup code.">
      <CodeForm label="Code" submit={(c) => m.mutate(c)} loading={m.isPending} error={m.error?.message} />
    </AuthLayout>
  );
}

function Setup({ stage, onDone }: { stage: Extract<Stage, { kind: "setup" }>; onDone: (token: string, codes: string[]) => void }) {
  const m = useMutation({
    mutationFn: (code: string) => unwrap(api.POST("/admin/auth/totp/verify", { body: { ticket: stage.ticket, code } }), { silent401: true }),
    onSuccess: (r) => onDone(r.access_token, r.backup_codes),
  });
  return (
    <AuthLayout title="Set up two-step sign in" subtitle="Scan this with an authenticator app (Google Authenticator, Authy, 1Password), then enter the code it shows.">
      <div className="mb-4 flex flex-col items-center gap-2">
        <div className="rounded-lg border border-border bg-white p-3">
          <QRCodeSVG value={stage.uri} size={156} title="Authenticator QR code" />
        </div>
        <p className="text-xs text-fg-muted">
          Cannot scan? Enter this key: <span className="font-mono text-fg">{stage.secret}</span>
        </p>
      </div>
      <CodeForm label="6-digit code" submit={(c) => m.mutate(c)} loading={m.isPending} error={m.error ? errorMessage({ detail: m.error.message }) : undefined} />
    </AuthLayout>
  );
}
