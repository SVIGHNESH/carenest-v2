const KEY = "carenest.admin.theme";

export function applyTheme(t: "light" | "dark") {
  document.documentElement.classList.toggle("dark", t === "dark");
  localStorage.setItem(KEY, t);
}

export function initTheme() {
  const saved = localStorage.getItem(KEY) as "light" | "dark" | null;
  applyTheme(saved ?? (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"));
}

export const currentTheme = () => (document.documentElement.classList.contains("dark") ? "dark" : "light");
