import { describe, it, expect, vi, beforeEach } from "vitest";
import { nextTick } from "vue";

// Mock fetch
const mockFetch = vi.fn();
global.fetch = mockFetch as any;

// Mock onMounted to run immediately
vi.mock("vue", async () => {
  const actual = await vi.importActual("vue");
  return {
    ...actual,
    onMounted: (fn: () => void | Promise<void>) => {
      Promise.resolve(fn());
    },
  };
});

import { useJsonFetch } from "@/composables/useJsonFetch";

describe("useJsonFetch", () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  it("returns loading=true initially", () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    const { loading } = useJsonFetch("/test.json");
    expect(loading.value).toBe(true);
  });

  it("sets data on successful fetch", async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ name: "test" }),
    });
    const { data, loading } = useJsonFetch("/test.json");
    await nextTick();
    await nextTick();
    expect(data.value).toEqual({ name: "test" });
    expect(loading.value).toBe(false);
  });

  it("sets error on HTTP error", async () => {
    mockFetch.mockResolvedValue({ ok: false, status: 404 });
    const { error, loading } = useJsonFetch("/missing.json");
    await nextTick();
    await nextTick();
    expect(error.value).toBe("HTTP 404");
    expect(loading.value).toBe(false);
  });

  it("sets error on network failure", async () => {
    mockFetch.mockRejectedValue(new Error("Network error"));
    const { error, loading } = useJsonFetch("/fail.json");
    await nextTick();
    await nextTick();
    expect(error.value).toBe("Network error");
    expect(loading.value).toBe(false);
  });

  it("accepts function URL", () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    const { loading } = useJsonFetch(() => "/dynamic.json");
    expect(loading.value).toBe(true);
    expect(mockFetch).toHaveBeenCalledWith("/dynamic.json");
  });
});
