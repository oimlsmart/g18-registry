import { ref, onMounted, type Ref } from "vue";

export function useJsonFetch<T = any>(url: string | (() => string)) {
  const data = ref<T | null>(null) as Ref<T | null>;
  const loading = ref(true);
  const error = ref<string | null>(null);

  onMounted(async () => {
    try {
      const u = typeof url === "function" ? url() : url;
      const res = await fetch(u);
      if (res.ok) {
        data.value = await res.json();
      } else {
        error.value = `HTTP ${res.status}`;
      }
    } catch (e) {
      error.value = e instanceof Error ? e.message : "Fetch failed";
    } finally {
      loading.value = false;
    }
  });

  return { data, loading, error };
}
