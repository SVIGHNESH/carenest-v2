import createClient, { type Middleware } from "openapi-fetch";
import type { components, paths } from "./schema";

export type Schemas = components["schemas"];

const TOKEN_KEY = "carenest.admin.token";
export const tokenStore = {
  get: () => sessionStorage.getItem(TOKEN_KEY),
  set: (t: string) => sessionStorage.setItem(TOKEN_KEY, t),
  clear: () => sessionStorage.removeItem(TOKEN_KEY),
};

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

let onUnauthorized: () => void = () => {};
export const setUnauthorizedHandler = (fn: () => void) => (onUnauthorized = fn);

const auth: Middleware = {
  onRequest({ request }) {
    const t = tokenStore.get();
    if (t) request.headers.set("Authorization", `Bearer ${t}`);
    return request;
  },
};

export const api = createClient<paths>({ baseUrl: import.meta.env.VITE_API_URL ?? "http://localhost:8000" });
api.use(auth);

/** FastAPI errors come as {detail: string} or {detail: [{msg, loc}]}. */
export function errorMessage(error: unknown): string {
  const detail = (error as { detail?: unknown } | undefined)?.detail;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    return detail.map((d: { msg?: string }) => (d.msg ?? "").replace(/^Value error, /, "")).filter(Boolean).join(". ") || "Check the form and try again.";
  }
  return "Something went wrong. Please try again.";
}

/** Unwraps an openapi-fetch result or throws ApiError. */
export async function unwrap<T>(p: Promise<{ data?: T; error?: unknown; response: Response }>, opts?: { silent401?: boolean }): Promise<T> {
  const { data, error, response } = await p;
  if (response.status === 401 && !opts?.silent401) onUnauthorized();
  if (error !== undefined || !response.ok) throw new ApiError(errorMessage(error), response.status);
  return data as T;
}
