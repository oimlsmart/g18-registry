<script setup lang="ts">
import { computed } from "vue";
import type { PaginationState } from "@/composables/usePagination";

const props = defineProps<{
  pagination: PaginationState<any>;
}>();

// Render a compact list of page numbers with ellipses, e.g.
// 1 … 4 5 [6] 7 8 … 12
const pages = computed<(number | "…")[]>(() => {
  const pc = props.pagination.pageCount.value;
  const cur = props.pagination.page.value;
  if (pc <= 9) return Array.from({ length: pc }, (_, i) => i + 1);
  const out: (number | "…")[] = [1];
  const start = Math.max(2, cur - 2);
  const end = Math.min(pc - 1, cur + 2);
  if (start > 2) out.push("…");
  for (let i = start; i <= end; i++) out.push(i);
  if (end < pc - 1) out.push("…");
  out.push(pc);
  return out;
});
</script>

<template>
  <div v-if="pagination.total.value > 0" class="pagination">
    <span class="pagination-count">
      Showing <strong>{{ pagination.start.value }}</strong>–<strong>{{ pagination.end.value }}</strong>
      of <strong>{{ pagination.total.value }}</strong>
    </span>
    <div class="pagination-controls">
      <button class="pagination-btn"
              :disabled="pagination.page.value <= 1"
              @click="pagination.setPage(pagination.page.value - 1)"
              aria-label="Previous page">‹</button>
      <template v-for="(p, i) in pages" :key="i">
        <span v-if="p === '…'" class="pagination-ellipsis">…</span>
        <button v-else
                :class="['pagination-btn', { 'pagination-btn-active': p === pagination.page.value }]"
                @click="pagination.setPage(p as number)">{{ p }}</button>
      </template>
      <button class="pagination-btn"
              :disabled="pagination.page.value >= pagination.pageCount.value"
              @click="pagination.setPage(pagination.page.value + 1)"
              aria-label="Next page">›</button>
    </div>
  </div>
</template>
