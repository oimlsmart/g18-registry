<script setup lang="ts">
// Renders definition text that may contain VIM cross-reference markup
// like {{3.1,measuring instrument}}. Converts each reference to a link
// to the matching term in this registry. Falls back to plain text if
// no matching term slug is found.
import { computed } from "vue";

const props = defineProps<{ text: string }>();

const segments = computed(() => {
  if (!props.text) return [{ kind: "text", value: "" }];
  const out: { kind: "text" | "xref"; value: string; slug?: string }[] = [];
  const re = /\{\{([^,}]+),([^}]+)\}\}/g;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(props.text)) !== null) {
    if (m.index > last) out.push({ kind: "text", value: props.text.slice(last, m.index) });
    const refId = m[1].trim();
    const refText = m[2].trim();
    const slug = refText.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    out.push({ kind: "xref", value: refText, slug });
    last = m.index + m[0].length;
  }
  if (last < props.text.length) out.push({ kind: "text", value: props.text.slice(last) });
  return out;
});
</script>

<template>
  <span class="def-text">
    <template v-for="(seg, i) in segments" :key="i">
      <span v-if="seg.kind === 'text'">{{ seg.value }}</span>
      <SLink v-else :to="`/terms/${seg.slug}/`" class="xref">{{ seg.value }}</SLink>
    </template>
  </span>
</template>

<style scoped>
.def-text { white-space: pre-wrap; }
.xref {
  border-bottom: 1px dotted currentColor;
  font-weight: 500;
}
.xref:hover { border-bottom-style: solid; }
</style>
