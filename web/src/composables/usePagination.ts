// Reusable pagination for long worklists (actions, terms, harmonization).
// Default 50 rows; users can switch to "All" via the page-size selector in
// the PaginationControls footer. Reset to page 1 whenever the upstream
// filter/sort changes — pass the filter signature via `dep` so the watcher
// fires.

import { computed, ref, watch, type Ref, type ComputedRef } from "vue";

export interface PaginationState<T> {
  page: Ref<number>;
  pageSize: Ref<number | "all">;
  pageSizes: (number | "all")[];
  pageCount: ComputedRef<number>;
  total: ComputedRef<number>;
  visible: ComputedRef<T[]>;
  start: ComputedRef<number>;
  end: ComputedRef<number>;
  setPage: (n: number) => void;
  setPageSize: (s: number | "all") => void;
}

export function usePagination<T>(
  source: ComputedRef<T[]> | Ref<T[]>,
  opts: { pageSize?: number; pageSizes?: (number | "all")[]; dep?: () => any } = {},
): PaginationState<T> {
  const pageSizes = opts.pageSizes ?? [50, 100, 200, "all"];
  const pageSize = ref<number | "all">(opts.pageSize ?? 50);
  const page = ref(1);

  const effectiveSize = computed(() => {
    const s = pageSize.value;
    if (s === "all") return Number.MAX_SAFE_INTEGER;
    return s;
  });

  const visible = computed(() => {
    const items = source.value;
    const start = (page.value - 1) * effectiveSize.value;
    return items.slice(start, start + effectiveSize.value);
  });

  const total = computed(() => source.value.length);
  const pageCount = computed(() =>
    Math.max(1, Math.ceil(total.value / Math.max(1, effectiveSize.value)))
  );
  const start = computed(() => total.value === 0 ? 0 : (page.value - 1) * effectiveSize.value + 1);
  const end = computed(() => Math.min(page.value * effectiveSize.value, total.value));

  function setPage(n: number) {
    if (n < 1) n = 1;
    if (n > pageCount.value) n = pageCount.value;
    page.value = n;
    if (typeof window !== "undefined") window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function setPageSize(s: number | "all") {
    pageSize.value = s;
    page.value = 1;
  }

  // Reset to page 1 when the filter/sort signature changes.
  if (opts.dep) {
    watch(opts.dep, () => { page.value = 1; });
  }

  return { page, pageSize, pageSizes, pageCount, total, visible, start, end, setPage, setPageSize };
}
