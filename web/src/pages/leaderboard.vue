<script setup lang="ts">
import { computed } from "vue";
import terms from "@/data/terms.json";
function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
const top = computed(() => (terms as any[])
  .map(t => ({ ...t, distinct: new Set(t.publications.map((p: any) => (p.definition || '').trim()).filter(Boolean)).size }))
  .filter(t => t.publications.length > 1)
  .sort((a, b) => {
    // Proper numeric comparison — NOT array comparison (JS coerces arrays to strings)
    if (b.distinct !== a.distinct) return b.distinct - a.distinct;
    if (b.publications.length !== a.publications.length) return b.publications.length - a.publications.length;
    return (a.name || "").localeCompare(b.name || "");
  })
  .slice(0, 20));
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><RouterLink to="/">Registry</RouterLink> / <span>Divergence</span></div>
    <h1>Divergence leaderboard</h1>
  </div>
  <section class="card">
    <table>
      <thead><tr><th>#</th><th>Term</th><th>VIM</th><th>Instances</th><th>Distinct defs</th></tr></thead>
      <tbody>
        <tr v-for="(t, i) in top" :key="t.slug">
          <td class="num">{{ i + 1 }}</td>
          <td><RouterLink :to="`/terms/${t.slug}/`">{{ t.name }}</RouterLink></td>
          <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
          <td class="num">{{ t.publications.length }}</td>
          <td class="num"><span class="divergence-count">{{ t.distinct }}</span></td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
