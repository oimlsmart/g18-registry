<script setup lang="ts">
import { ref, onMounted } from "vue";

const base = import.meta.env.BASE_URL;
const logoSrc = `${base}oiml-logo.svg`;

// Three groups, ordered by user task:
//   Triage  — what TC 1 needs to work on
//   Browse  — explore the registry
//   Dataset — structural issues / edition diff
const navGroups: { items: { href: string; label: string }[] }[] = [
  {
    items: [
      { href: "actions/", label: "Actions" },
      { href: "harmonization/", label: "Harmonise" },
    ],
  },
  {
    items: [
      { href: "terms/", label: "Terms" },
      { href: "publications/", label: "Publications" },
      { href: "tc/", label: "TC / SC" },
    ],
  },
  {
    items: [
      { href: "conflicts/", label: "ID Conflicts" },
      { href: "editions/", label: "Editions" },
    ],
  },
];

// Mobile hamburger state. Defaults to `false` so SSR and client agree.
const menuOpen = ref(false);

function closeMenu() { menuOpen.value = false; }

// Close the menu if the viewport grows back to desktop size.
onMounted(() => {
  const mq = window.matchMedia("(min-width: 880px)");
  const handler = (e: MediaQueryListEvent) => { if (e.matches) closeMenu(); };
  mq.addEventListener("change", handler);
});
</script>

<template>
  <header class="sticky top-0 z-20 bg-white border-b border-rule shadow-sm">
    <div class="mx-auto max-w-[1080px] flex items-center justify-between gap-2 px-6 max-sm:px-4 py-2 relative">
      <a class="flex items-center gap-3 font-semibold no-underline text-ink hover:no-underline" :href="base" @click="closeMenu">
        <img :src="logoSrc" alt="OIML" class="block h-9 max-sm:h-8 w-auto" />
        <span class="flex flex-col leading-tight">
          <span class="text-base font-semibold text-accent">G 18 Registry</span>
          <span class="text-xs text-ink-muted max-sm:hidden">OIML Term-Usage Registry</span>
        </span>
      </a>
      <button
        class="md:hidden flex flex-col justify-center items-center gap-1 bg-transparent border-0 p-1.5 w-8 h-7 cursor-pointer rounded hover:bg-rule-soft"
        :class="menuOpen ? 'is-open' : ''"
        :aria-expanded="menuOpen"
        aria-label="Toggle navigation menu"
        @click="menuOpen = !menuOpen"
      >
        <span class="block h-[1.5px] w-5 bg-ink rounded-sm transition-all duration-200"
              :style="menuOpen ? 'transform: translateY(5.5px) rotate(45deg)' : ''" />
        <span class="block h-[1.5px] w-5 bg-ink rounded-sm transition-all duration-200"
              :style="menuOpen ? 'opacity: 0; transform: scaleX(0)' : ''" />
        <span class="block h-[1.5px] w-5 bg-ink rounded-sm transition-all duration-200"
              :style="menuOpen ? 'transform: translateY(-5.5px) rotate(-45deg)' : ''" />
      </button>
      <nav class="hidden md:flex items-center gap-4" aria-label="Primary">
        <template v-for="(group, gi) in navGroups" :key="gi">
          <span v-if="gi > 0" class="inline-block w-px self-stretch bg-rule mx-1" aria-hidden="true" />
          <a v-for="n in group.items" :key="n.href"
             class="text-ink-muted text-[0.95em] py-1 border-b-2 border-transparent hover:text-accent hover:border-accent hover:no-underline whitespace-nowrap"
             :href="base + n.href"
             @click="closeMenu">{{ n.label }}</a>
        </template>
      </nav>

      <!-- Mobile dropdown: visible only when menu is open. Tailwind handles
           the desktop hiding via `md:hidden` on the toggle button above;
           the nav panel itself uses `md:hidden + conditional flex`. -->
      <nav v-if="menuOpen"
           class="md:hidden absolute left-0 right-0 top-full bg-white border-t border-b border-rule shadow-lg px-6 py-2 z-30 max-h-[calc(100vh-64px)] overflow-y-auto flex flex-col"
           aria-label="Primary mobile">
        <template v-for="(group, gi) in navGroups" :key="gi">
          <div v-if="gi > 0" class="h-px bg-rule-soft my-2" />
          <a v-for="n in group.items" :key="n.href"
             class="text-ink py-3 border-b border-rule-soft last:border-b-0 hover:text-accent hover:no-underline"
             :href="base + n.href"
             @click="closeMenu">{{ n.label }}</a>
        </template>
      </nav>
    </div>
  </header>
  <main class="mx-auto max-w-[1080px] px-6 max-sm:px-4 py-6 max-sm:py-4 min-h-[70vh]">
    <RouterView />
  </main>
  <footer class="bg-oiml-brand-900 text-[#d1d5db] mt-12 pt-8 pb-6 text-sm border-t-4 border-oiml-brand-600">
    <div class="mx-auto max-w-[1080px] px-6 max-sm:px-4 grid grid-cols-1 md:grid-cols-[1fr_auto] gap-4 items-end">
      <div>
        <strong>G 18 — OIML Term-Usage Registry</strong><br />
        Source: <a class="text-oiml-brand-300" href="https://github.com/oimlsmart/vocab/tree/main/datasets/g18-2010">oimlsmart/vocab</a>.
        VIM/VIML: <a class="text-oiml-brand-300" href="https://oimlsmart.github.io/vocab/">oimlsmart.github.io/vocab</a>.
      </div>
      <div class="md:text-right md:border-l md:border-[#334155] md:pl-6">
        <strong>OIML SMART.</strong> Digital service by <a class="text-oiml-brand-300 font-semibold" href="https://www.ribose.com">Ribose</a>.
      </div>
    </div>
  </footer>
</template>

<style>
@import "./styles/global.css";
</style>
