<script setup lang="ts">
import { computed } from "vue";
import { resolveXrefSlug } from "@/utils/xref-resolver";

const props = defineProps<{ text: string }>();
const base = import.meta.env.BASE_URL;

const rendered = computed(() => {
  if (!props.text) return "";
  return props.text.replace(
    /\{\{([^,}]+),([^}]+)\}\}/g,
    (_match: string, id: string, text: string) => {
      const trimmedText = text.trim();
      const slug = resolveXrefSlug(id.trim(), trimmedText);
      if (slug) {
        return `<a href="${base}concepts/${slug}/" class="xref">${trimmedText}</a>`;
      }
      return `<span class="xref-unresolved" title="Not in G 18 — see VIM/VIML vocab">${trimmedText}</span>`;
    }
  );
});
</script>

<template>
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
.def-text :deep(.xref-unresolved) {
  border-bottom: 1px dotted var(--color-ink-muted);
  color: var(--color-ink-soft);
  font-style: italic;
  cursor: help;
}
</style>
