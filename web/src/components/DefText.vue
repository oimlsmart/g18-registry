<script setup lang="ts">
// Renders definition/designation text that may contain:
//   1. VIM cross-references: {{3.1,measuring instrument}} → clickable link
//   2. Pre-rendered MathML: <math>...</math> → displayed as-is (v-html)
//
// MathML is pre-rendered by Plurimath (Ruby) at export time; the frontend
// just renders it via v-html. Cross-references are converted client-side
// because the slug depends on the frontend's slugify convention.
import { computed } from "vue";

const props = defineProps<{ text: string }>();
const base = import.meta.env.BASE_URL;

const rendered = computed(() => {
  if (!props.text) return "";
  let html = props.text;
  // Convert {{id,text}} → <a href="<base>/terms/<slug>/">text</a>
  html = html.replace(
    /\{\{([^,}]+),([^}]+)\}\}/g,
    (_match: string, _id: string, text: string) => {
      const slug = text.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
      return `<a href="${base}terms/${slug}/" class="xref">${text.trim()}</a>`;
    }
  );
  return html;
});
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -- pre-rendered MathML + linkified cross-refs. No user input. -->
  <span class="def-text" v-html="rendered" />
</template>

<style scoped>
.def-text { white-space: pre-wrap; }
.def-text :deep(math) { font-size: 1.05em; }
.def-text :deep(.xref) {
  border-bottom: 1px dotted currentColor;
  font-weight: 500;
  color: var(--color-accent);
  text-decoration: none;
}
.def-text :deep(.xref:hover) {
  border-bottom-style: solid;
  text-decoration: none;
}
</style>
