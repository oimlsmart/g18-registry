<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from "vue";
import { useRoute } from "vue-router";
import { useTheme } from "@/composables/useTheme";

const route = useRoute();
const base = import.meta.env.BASE_URL;
const { theme, toggleTheme } = useTheme();
const logoSrc = `${base}oiml-logo.svg`;
const logoDarkSrc = `${base}oiml-logo-dark.svg`;

// Primary nav (always visible at desktop). Items here are what TC 1
// reaches for every session.
const primaryNav = [
  { href: "actions/", label: "Actions" },
  { href: "proposals/", label: "Proposals" },
  { href: "terms/", label: "Terms" },
  { href: "publications/", label: "Publications" },
];

// "More" dropdown — less-frequently-visited pages. Kept out of the
// primary nav so the bar stays scannable.
const moreNav = [
  { href: "harmonization/", label: "Defn conflicts" },
  { href: "conflicts/", label: "ID conflicts" },
  { href: "tc/", label: "TC / SC" },
  { href: "editions/", label: "Editions" },
];

// Mobile hamburger state. Defaults to `false` so SSR and client agree.
const menuOpen = ref(false);
function closeMenu() { menuOpen.value = false; }

// Desktop "More" dropdown state. Closes on outside click or Escape.
const moreOpen = ref(false);
const moreRef = ref<HTMLElement | null>(null);

function onDocClick(e: MouseEvent) {
  if (moreRef.value && !moreRef.value.contains(e.target as Node)) {
    moreOpen.value = false;
  }
}
function onKey(e: KeyboardEvent) { if (e.key === "Escape") moreOpen.value = false; }

// Check if a nav item matches the current page. `href` is relative
// (e.g. "actions/"); the current path is the router's path minus
// the base.
function isActive(href: string): boolean {
  const current = route.path.replace(base, "").replace(/\/$/, "");
  const target = href.replace(/\/$/, "");
  if (target === "") return current === "";
  return current === target || current.startsWith(target + "/");
}
const activePrimary = computed(() => primaryNav.find(n => isActive(n.href)));
const activeMore = computed(() => moreNav.find(n => isActive(n.href)));

// Close the menu if the viewport grows back to desktop size.
onMounted(() => {
  const mq = window.matchMedia("(min-width: 880px)");
  const handler = (e: MediaQueryListEvent) => { if (e.matches) closeMenu(); };
  mq.addEventListener("change", handler);
  document.addEventListener("click", onDocClick);
  document.addEventListener("keydown", onKey);
});
onUnmounted(() => {
  document.removeEventListener("click", onDocClick);
  document.removeEventListener("keydown", onKey);
});
</script>

<template>
  <header class="sticky top-0 z-30 bg-paper-soft/95 backdrop-blur-sm border-b border-rule">
    <div class="mx-auto max-w-[1080px] flex items-center justify-between gap-4 px-6 max-sm:px-4 h-16">
      <a class="flex items-center gap-3 no-underline text-ink hover:no-underline group" :href="base" @click="closeMenu">
        <img :src="theme === 'dark' ? logoDarkSrc : logoSrc" alt="OIML" class="block h-7 w-auto shrink-0 transition-transform group-hover:scale-[1.03]" width="28" height="24" />
        <span style="font-family: var(--font-display); font-weight: 500; font-size: 1.125rem; letter-spacing: -0.02em; color: var(--color-ink); line-height: 1.2; font-variation-settings: 'opsz' 48, 'SOFT' var(--display-soft, 30), 'WONK' var(--display-wonk, 0);">OIML Terminology Harmonization</span>
      </a>

      <div class="flex items-center gap-2">
        <!-- Mobile hamburger -->
        <button
          class="md:hidden flex flex-col justify-center items-center gap-[3px] bg-transparent border-0 p-2 w-9 h-9 cursor-pointer rounded hover:bg-rule-soft"
          :aria-expanded="menuOpen"
          aria-label="Toggle navigation menu"
          @click="menuOpen = !menuOpen"
        >
          <span class="block h-[1.5px] w-5 bg-ink rounded-full transition-all duration-200"
                :style="menuOpen ? 'transform: translateY(4.5px) rotate(45deg)' : ''" />
          <span class="block h-[1.5px] w-5 bg-ink rounded-full transition-all duration-200"
                :style="menuOpen ? 'opacity: 0; transform: scaleX(0)' : ''" />
          <span class="block h-[1.5px] w-5 bg-ink rounded-full transition-all duration-200"
                :style="menuOpen ? 'transform: translateY(-4.5px) rotate(-45deg)' : ''" />
        </button>

        <!-- Desktop primary nav + "More" dropdown -->
        <nav class="hidden md:flex items-center text-[13px]" aria-label="Primary">
          <a v-for="n in primaryNav" :key="n.href"
             :class="['px-2.5 py-1.5 rounded transition-colors no-underline font-medium whitespace-nowrap',
                       isActive(n.href) ? 'bg-accent-tint text-accent' : 'text-ink-soft hover:text-accent hover:bg-accent-tint']"
             :href="base + n.href"
             @click="closeMenu">{{ n.label }}</a>

          <!-- "More" dropdown -->
          <div ref="moreRef" class="relative">
            <button
              type="button"
              :class="['px-2.5 py-1.5 rounded transition-colors font-medium flex items-center gap-1',
                        activeMore ? 'bg-accent-tint text-accent' : 'text-ink-soft hover:text-accent hover:bg-accent-tint']"
              :aria-expanded="moreOpen"
              aria-haspopup="true"
              @click="moreOpen = !moreOpen">
              More
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <polyline points="6 9 12 15 18 9" />
              </svg>
            </button>
            <div v-if="moreOpen" class="more-dropdown" role="menu">
              <a v-for="n in moreNav" :key="n.href"
                 :class="['more-dropdown-item', { 'more-dropdown-item-active': isActive(n.href) }]"
                 role="menuitem"
                 :href="base + n.href"
                 @click="moreOpen = false">{{ n.label }}</a>
            </div>
          </div>
        </nav>

        <!-- Theme toggle (rightmost) -->
        <button
          type="button"
          class="theme-toggle"
          :aria-label="theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'"
          :title="theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'"
          @click="toggleTheme">
          <svg v-if="theme === 'dark'" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
          </svg>
          <svg v-else width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
          </svg>
        </button>
      </div>
    </div>

    <!-- Mobile dropdown -->
    <nav v-if="menuOpen"
         class="md:hidden absolute left-0 right-0 top-full bg-paper-soft border-b border-rule shadow-lg px-4 py-3 z-40 max-h-[calc(100vh-64px)] overflow-y-auto"
         aria-label="Primary mobile">
      <a v-for="n in primaryNav" :key="n.href"
         class="block px-3 py-2.5 text-[15px] text-ink rounded hover:bg-accent-tint hover:text-accent hover:no-underline font-medium"
         :href="base + n.href"
         @click="closeMenu">{{ n.label }}</a>
      <div class="h-px bg-rule-soft my-2 mx-1" />
      <span class="block px-3 py-1 text-[10.5px] uppercase tracking-[0.12em] font-semibold text-ink-muted">More</span>
      <a v-for="n in moreNav" :key="n.href"
         class="block px-3 py-2.5 text-[14px] text-ink-soft rounded hover:bg-accent-tint hover:text-accent hover:no-underline font-medium"
         :href="base + n.href"
         @click="closeMenu">{{ n.label }}</a>
    </nav>
  </header>

  <main class="mx-auto max-w-[1080px] px-6 max-sm:px-4 py-10 max-sm:py-6 min-h-[70vh]">
    <RouterView />
  </main>

  <footer class="bg-oiml-brand-900 text-oiml-brand-200 mt-20 py-10 text-[13px]">
    <div class="mx-auto max-w-[1080px] px-6 max-sm:px-4 grid grid-cols-1 md:grid-cols-[auto_1fr_auto] gap-6 items-start">
      <div class="flex items-center gap-3">
        <img :src="theme === 'dark' ? logoDarkSrc : logoSrc" alt="OIML" class="block h-8 w-auto shrink-0" width="32" height="28" />
      </div>
      <div class="space-y-1.5">
        <div class="text-white" style="font-family: var(--font-display); font-weight: 500; font-size: 1.05rem; letter-spacing: -0.015em;">OIML Terminology Harmonization</div>
        <div>
          Source: <a class="text-oiml-brand-300 hover:text-white underline" href="https://github.com/oimlsmart/vocab/tree/main/datasets/g18-2010">oimlsmart/vocab</a>
          · VIM/VIML: <a class="text-oiml-brand-300 hover:text-white underline" href="https://oimlsmart.github.io/vocab/">oimlsmart.github.io/vocab</a>
        </div>
      </div>
      <div class="md:text-right md:border-l md:border-oiml-brand-700 md:pl-6">
        <div class="text-white font-semibold">OIML SMART</div>
        <div>Digital service by <a class="text-oiml-brand-300 hover:text-white underline font-medium" href="https://www.ribose.com">Ribose</a></div>
      </div>
    </div>
  </footer>
</template>

<style>
@import "./styles/global.css";

/* Theme toggle button — sun/moon icon */
.theme-toggle {
  appearance: none;
  background: transparent;
  border: 1px solid var(--color-rule);
  color: var(--color-ink-soft);
  width: 36px;
  height: 36px;
  border-radius: 4px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.15s, color 0.15s, border-color 0.15s;
}
.theme-toggle:hover {
  background: var(--color-paper-tint);
  color: var(--color-accent);
  border-color: var(--color-ink-muted);
}

/* "More" dropdown */
.more-dropdown {
  position: absolute;
  top: 100%;
  right: 0;
  min-width: 12em;
  margin-top: 0.3em;
  background: var(--color-paper-soft);
  border: 1px solid var(--color-rule);
  border-radius: 4px;
  box-shadow: 0 4px 12px -4px rgba(10, 22, 40, 0.12);
  padding: 0.4em 0;
  z-index: 50;
  display: flex;
  flex-direction: column;
}
.more-dropdown-item {
  display: block;
  padding: 0.5em 0.9em;
  color: var(--color-ink-soft);
  font-size: 0.92rem;
  text-decoration: none;
  white-space: nowrap;
  transition: background 0.1s, color 0.1s;
}
.more-dropdown-item:hover {
  background: var(--color-accent-tint);
  color: var(--color-accent);
  text-decoration: none;
}
.more-dropdown-item-active {
  background: var(--color-accent-tint);
  color: var(--color-accent);
  font-weight: 600;
}
</style>
