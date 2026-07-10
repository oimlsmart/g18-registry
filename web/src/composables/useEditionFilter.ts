import { ref, computed, type Ref, type ComputedRef } from "vue";

export type EditionFilter = "202X" | "2010" | "all";

export interface EditionFilterState {
  filter: Ref<EditionFilter>;
  setFilter: (f: EditionFilter) => void;
  enabledEditions: ComputedRef<Set<string>>;
}

export function useEditionFilter(
  editionsPresent: ComputedRef<string[]> | Ref<string[]>,
  defaultFilter: EditionFilter = "202X",
): EditionFilterState {
  const filter = ref<EditionFilter>(defaultFilter);

  const enabledEditions = computed(() => {
    const eds = typeof editionsPresent === "function"
      ? (editionsPresent as ComputedRef<string[]>).value
      : (editionsPresent as Ref<string[]>).value;
    if (filter.value === "all") return new Set(eds);
    return new Set(eds.filter(e => e === filter.value));
  });

  function setFilter(f: EditionFilter) {
    filter.value = f;
  }

  return { filter, setFilter, enabledEditions };
}
