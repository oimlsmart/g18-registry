// Theme switcher. Persists user choice in localStorage; defaults to
// prefers-color-scheme on first visit. SSR-safe: the data-theme attribute
// is set in main.ts AFTER hydration to avoid mismatches with the SSG
// pre-rendered HTML (which assumes light theme by default).

import { ref } from "vue";

export type Theme = "light" | "dark";

const STORAGE_KEY = "g18-registry-theme";

const theme = ref<Theme>("light");

function applyTheme(t: Theme) {
  if (typeof document === "undefined") return;
  document.documentElement.setAttribute("data-theme", t);
}

function detectInitialTheme(): Theme {
  if (typeof window === "undefined") return "light";
  const stored = window.localStorage.getItem(STORAGE_KEY);
  if (stored === "light" || stored === "dark") return stored;
  if (window.matchMedia?.("(prefers-color-scheme: dark)").matches) return "dark";
  return "light";
}

export function initTheme() {
  theme.value = detectInitialTheme();
  applyTheme(theme.value);
  // Re-apply on system pref change ONLY if the user hasn't made an
  // explicit choice.
  if (typeof window !== "undefined" && window.matchMedia) {
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
      if (!window.localStorage.getItem(STORAGE_KEY)) {
        theme.value = e.matches ? "dark" : "light";
        applyTheme(theme.value);
      }
    });
  }
}

export function toggleTheme() {
  theme.value = theme.value === "dark" ? "light" : "dark";
  applyTheme(theme.value);
  if (typeof window !== "undefined") {
    window.localStorage.setItem(STORAGE_KEY, theme.value);
  }
}

export function useTheme() {
  return { theme, toggleTheme };
}
