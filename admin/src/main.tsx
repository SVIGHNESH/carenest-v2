import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { Toaster } from "sonner";
import { ApiError, setUnauthorizedHandler, tokenStore } from "@/api/client";
import { initTheme } from "@/lib/theme";
import { router } from "./router";
import "./index.css";

initTheme();

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 15_000, retry: (n, e) => !(e instanceof ApiError && e.status < 500) && n < 2, refetchOnWindowFocus: true },
  },
});

setUnauthorizedHandler(() => {
  tokenStore.clear();
  queryClient.clear();
  if (!location.pathname.startsWith("/login")) router.navigate({ to: "/login" });
});

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
      <Toaster position="bottom-right" richColors closeButton />
    </QueryClientProvider>
  </StrictMode>,
);
