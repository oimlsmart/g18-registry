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
  <header class="sticky top-0 z-30 bg-white/95 backdrop-blur-sm border-b border-rule">
    <div class="mx-auto max-w-[1080px] flex items-center justify-between gap-4 px-6 max-sm:px-4 h-14">
      <a class="flex items-center gap-2.5 no-underline text-ink hover:no-underline" :href="base" @click="closeMenu">
        <img :src="logoSrc" alt="OIML" class="block h-7 w-auto shrink-0" />
        <span class="flex flex-col leading-none">
          <span class="text-[15px] font-semibold tracking-tight text-accent">G 18 Registry</span>
          <span class="text-[11px] text-ink-muted mt-0.5 max-sm:hidden">OIML Term-Usage Registry</span>
        </span>
      </a>

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

      <nav class="hidden md:flex items-center gap-3 text-[14px]" aria-label="Primary">
        <template v-for="(group, gi) in navGroups" :key="gi">
          <span v-if="gi > 0" class="h-5 w-px bg-rule" aria-hidden="true" />
          <a v-for="n in group.items" :key="n.href"
             class="px-2 py-1.5 rounded text-ink-soft hover:text-accent hover:bg-oiml-brand-50 transition-colors no-underline"
             :href="base + n.href"
             @click="closeMenu">{{ n.label }}</a>
        </template>
      </nav>
    </div>

    <!-- Mobile dropdown -->
    <nav v-if="menuOpen"
         class="md:hidden absolute left-0 right-0 top-full bg-white border-b border-rule shadow-lg px-4 py-2 z-40 max-h-[calc(100vh-56px)] overflow-y-auto"
         aria-label="Primary mobile">
      <template v-for="(group, gi) in navGroups" :key="gi">
        <div v-if="gi > 0" class="h-px bg-rule-soft my-1.5 mx-2" />
        <a v-for="n in group.items" :key="n.href"
           class="block px-3 py-2.5 text-[15px] text-ink rounded hover:bg-oiml-brand-50 hover:text-accent hover:no-underline"
           :href="base + n.href"
           @click="closeMenu">{{ n.label }}</a>
      </template>
    </nav>
  </header>

  <main class="mx-auto max-w-[1080px] px-6 max-sm:px-4 py-8 max-sm:py-5 min-h-[70vh]">
    <RouterView />
  </main>

  <footer class="bg-oiml-brand-900 text-oiml-brand-200 mt-16 py-8 text-[13px]">
    <div class="mx-auto max-w-[1080px] px-6 max-sm:px-4 grid grid-cols-1 md:grid-cols-[1fr_auto] gap-6 items-end">
      <div class="space-y-1">
        <div class="text-white font-semibold">G 18 — OIML Term-Usage Registry</div>
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
</style>
