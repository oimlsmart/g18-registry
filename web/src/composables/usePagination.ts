// Reusable pagination for long worklists (actions, terms, harmonization).
// Pagesize 50 keeps the DOM light and gives users a sane scan target.
// Reset to page 1 whenever the upstream filter/sort changes — pass the
// filter signature via `dep` so the watcher fires.

import { computed, ref, watch, type Ref, type ComputedRef } from "vue";

export interface PaginationState<T> {
  page: Ref<number>;
  pageSize: Ref<number>;
  pageCount: ComputedRef<number>;
  total: ComputedRef<number>;
  visible: ComputedRef<T[]>;
  start: ComputedRef<number>;
  end: ComputedRef<number>;
  setPage: (n: number) => void;
}

export function usePagination<T>(
  source: ComputedRef<T[]> | Ref<T[]>,
  opts: { pageSize?: number; dep?: () => any } = {},
): PaginationState<T> {
  const pageSize = ref(opts.pageSize ?? 50);
  const page = ref(1);

  const visible = computed(() => {
    const items = source.value;
    const start = (page.value - 1) * pageSize.value;
    return items.slice(start, start + pageSize.value);
  });

  const total = computed(() => source.value.length);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / pageSize.value)));
  const start = computed(() => total.value === 0 ? 0 : (page.value - 1) * pageSize.value + 1);
  const end = computed(() => Math.min(page.value * pageSize.value, total.value));

  function setPage(n: number) {
    if (n < 1) n = 1;
    if (n > pageCount.value) n = pageCount.value;
    page.value = n;
    if (typeof window !== "undefined") window.scrollTo({ top: 0, behavior: "smooth" });
  }

  // Reset to page 1 when the filter/sort signature changes.
  if (opts.dep) {
    watch(opts.dep, () => { page.value = 1; });
  }

  return { page, pageSize, pageCount, total, visible, start, end, setPage };
}
