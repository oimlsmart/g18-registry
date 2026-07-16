import { describe, it, expect } from "vitest";
import { ref, computed } from "vue";
import { useEditionFilter } from "@/composables/useEditionFilter";

describe("useEditionFilter", () => {
  it("initializes with the provided default filter", () => {
    const eds = ref(["202X", "2010"]);
    const { filter } = useEditionFilter(eds, "202X");
    expect(filter.value).toBe("202X");
  });

  it("defaults to '202X' when no default given", () => {
    const eds = ref(["202X"]);
    const { filter } = useEditionFilter(eds);
    expect(filter.value).toBe("202X");
  });

  it("setFilter updates the filter", () => {
    const eds = ref(["202X", "2010"]);
    const { filter, setFilter } = useEditionFilter(eds, "202X");
    setFilter("2010");
    expect(filter.value).toBe("2010");
  });

  it("enabledEditions returns all editions when filter is 'all'", () => {
    const eds = ref(["202X", "2010", "complete"]);
    const { filter, setFilter, enabledEditions } = useEditionFilter(eds, "202X");
    setFilter("all");
    expect(enabledEditions.value.size).toBe(3);
    expect(enabledEditions.value.has("202X")).toBe(true);
    expect(enabledEditions.value.has("complete")).toBe(true);
  });

  it("enabledEditions filters to just the selected edition", () => {
    const eds = ref(["202X", "2010", "complete"]);
    const { setFilter, enabledEditions } = useEditionFilter(eds, "all");
    setFilter("202X");
    expect(enabledEditions.value.size).toBe(1);
    expect(enabledEditions.value.has("202X")).toBe(true);
  });

  it("accepts a ComputedRef<string[]> as input", () => {
    const source = ref(["202X", "2010"]);
    const eds = computed(() => source.value);
    const { enabledEditions } = useEditionFilter(eds, "all");
    expect(enabledEditions.value.size).toBe(2);
  });

  it("reacts to changes in the source editions list", () => {
    const source = ref(["202X"]);
    const { enabledEditions } = useEditionFilter(source, "all");
    expect(enabledEditions.value.size).toBe(1);
    source.value = ["202X", "2010"];
    expect(enabledEditions.value.size).toBe(2);
  });

  it("reacts to filter changes", () => {
    const eds = ref(["202X", "2010"]);
    const { filter, enabledEditions } = useEditionFilter(eds, "all");
    expect(enabledEditions.value.size).toBe(2);
    filter.value = "2010";
    expect(enabledEditions.value.size).toBe(1);
    expect(enabledEditions.value.has("2010")).toBe(true);
  });

  it("returns empty set when editions list is empty", () => {
    const eds = ref<string[]>([]);
    const { enabledEditions } = useEditionFilter(eds, "all");
    expect(enabledEditions.value.size).toBe(0);
  });
});
