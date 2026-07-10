<script setup lang="ts">
import type { EditionFilter } from "@/composables/useEditionFilter";

defineProps<{
  modelValue: EditionFilter;
}>();
const emit = defineEmits<{ "update:modelValue": [EditionFilter] }>();

const buttons: { val: EditionFilter; title: string; meta: string }[] = [
  { val: "202X", title: "202X", meta: "draft · TC 1 acts here" },
  { val: "2010", title: "2010", meta: "published · read-only" },
  { val: "all", title: "All", meta: "both editions" },
];
</script>

<template>
  <div class="page-filter" role="region" aria-label="Edition filter">
    <span class="page-filter-label">Edition scope</span>
    <div class="page-filter-controls">
      <button v-for="b in buttons" :key="b.val"
              type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': modelValue === b.val }]"
              @click="emit('update:modelValue', b.val)">
        <span class="page-filter-btn-title">{{ b.title }}</span>
        <span class="page-filter-btn-meta">{{ b.meta }}</span>
      </button>
    </div>
  </div>
</template>
