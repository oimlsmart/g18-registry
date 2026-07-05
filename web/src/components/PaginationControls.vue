<script setup lang="ts">
import { computed } from "vue";
import type { PaginationState } from "@/composables/usePagination";

const props = defineProps<{
  pagination: PaginationState<any>;
  // Optional noun for the count sentence, e.g. "terms", "actions".
  // Defaults to a neutral "rows".
  noun?: string;
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

const noun = computed(() => props.noun || "rows");
</script>

<template>
  <div v-if="pagination.total.value > 0" class="pagination">
    <span class="pagination-count">
      Showing <strong>{{ pagination.start.value }}</strong>–<strong>{{ pagination.end.value }}</strong>
      of <strong>{{ pagination.total.value }}</strong> {{ noun }}
    </span>
    <div class="pagination-tools">
      <!-- Page-size selector: 50 / 100 / 200 / All -->
      <span class="pagination-sizer">
        <span class="pagination-sizer-label">Per page</span>
        <button v-for="s in pagination.pageSizes" :key="String(s)"
                type="button"
                :class="['pagination-btn', 'pagination-btn-mini', { 'pagination-btn-active': pagination.pageSize.value === s }]"
                @click="pagination.setPageSize(s)">
          {{ s === "all" ? "All" : s }}
        </button>
      </span>
      <!-- Page navigation: ‹ 1 … 4 5 [6] 7 8 … 12 › (hidden when All is selected) -->
      <div v-if="pagination.pageSize.value !== 'all'" class="pagination-controls">
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
  </div>
</template>

<style scoped>
.pagination-tools {
  display: inline-flex;
  align-items: center;
  gap: 1.2em;
  flex-wrap: wrap;
}
.pagination-sizer {
  display: inline-flex;
  align-items: center;
  gap: 0.3em;
}
.pagination-sizer-label {
  font-size: 0.78rem;
  color: var(--color-ink-muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 600;
  margin-right: 0.3em;
}
.pagination-btn-mini {
  padding: 0.25em 0.55em;
  min-width: 0;
  font-size: 0.8rem;
}
@media (max-width: 720px) {
  .pagination {
    justify-content: center;
    text-align: center;
  }
  .pagination-tools {
    justify-content: center;
    gap: 0.7em;
  }
}
</style>
