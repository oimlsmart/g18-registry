import { describe, it, expect } from "vitest";
import { usePagination } from "@/composables/usePagination";
import { ref, computed, nextTick } from "vue";

describe("usePagination", () => {
  it("slices visible items based on page + pageSize", () => {
    const source = computed(() => Array.from({ length: 100 }, (_, i) => i));
    const p = usePagination(source, { pageSize: 10 });
    expect(p.visible.value).toHaveLength(10);
    expect(p.visible.value[0]).toBe(0);
    p.setPage(2);
    expect(p.visible.value[0]).toBe(10);
  });

  it("computes correct total and page count", () => {
    const source = computed(() => Array.from({ length: 55 }, (_, i) => i));
    const p = usePagination(source, { pageSize: 10 });
    expect(p.total.value).toBe(55);
    expect(p.pageCount.value).toBe(6);
  });

  it("computes start and end indices", () => {
    const source = computed(() => Array.from({ length: 55 }, (_, i) => i));
    const p = usePagination(source, { pageSize: 10 });
    expect(p.start.value).toBe(1);
    expect(p.end.value).toBe(10);
    p.setPage(6);
    expect(p.start.value).toBe(51);
    expect(p.end.value).toBe(55);
  });

  it("supports 'all' page size", () => {
    const source = computed(() => Array.from({ length: 100 }, (_, i) => i));
    const p = usePagination(source, { pageSize: 10 });
    p.setPageSize("all");
    expect(p.visible.value).toHaveLength(100);
    expect(p.pageCount.value).toBe(1);
  });

  it("supports 100 and 200 page sizes", () => {
    const source = computed(() => Array.from({ length: 150 }, (_, i) => i));
    const p = usePagination(source, { pageSize: 50 });
    p.setPageSize(100);
    expect(p.visible.value).toHaveLength(100);
    p.setPageSize(200);
    expect(p.visible.value).toHaveLength(150);
  });

  it("resets to page 1 when dep changes", async () => {
    const depVal = ref("a");
    const source = computed(() => {
      depVal.value;
      return Array.from({ length: 50 }, (_, i) => i + (depVal.value === "b" ? 1000 : 0));
    });
    const p = usePagination(source, { pageSize: 10, dep: () => depVal.value });
    p.setPage(3);
    expect(p.page.value).toBe(3);
    depVal.value = "b";
    await nextTick();
    expect(p.page.value).toBe(1);
  });

  it("clamps page to valid range", () => {
    const source = computed(() => Array.from({ length: 25 }, (_, i) => i));
    const p = usePagination(source, { pageSize: 10 });
    p.setPage(99);
    expect(p.page.value).toBe(3); // max page
    p.setPage(-1);
    expect(p.page.value).toBe(1);
  });

  it("handles empty source", () => {
    const source = computed(() => []);
    const p = usePagination(source, { pageSize: 10 });
    expect(p.visible.value).toHaveLength(0);
    expect(p.total.value).toBe(0);
    expect(p.start.value).toBe(0);
    expect(p.pageCount.value).toBe(1);
  });
});
