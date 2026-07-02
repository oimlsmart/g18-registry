<script setup lang="ts">
import { ref, computed } from "vue";
import publications from "@/data/publications.json";
import terms from "@/data/terms.json";
const onlyEdition = ref("");
const filtered = computed(() => {
  if (!onlyEdition.value) return publications as any[];
  const pubIds = new Set<string>();
  for (const t of terms as any[]) {
    if (t.editions_present?.includes(onlyEdition.value)) {
      for (const p of t.publications || []) if (p.publication_id) pubIds.add(p.publication_id);
    }
  }
  return (publications as any[]).filter(p => pubIds.has(p.id));
});
function termCount(pubId: string, ed: string) {
  return (terms as any[]).filter(t => t.publications.some((p: any) => p.publication_id === pubId && (!ed || t.editions_present?.includes(ed)))).length;
}
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Publications</span></div>
    <h1>Publications</h1>
    <p class="lede">{{ (publications as any[]).length }} publications.</p>
  </div>
  <section class="card">
    <form style="margin-bottom:0.5em" @submit.prevent>
      <select v-model="onlyEdition"><option value="">All editions</option><option value="2010">2010 only</option><option value="202X">202X only</option></select>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>
    <table>
      <thead><tr><th>ID</th><th>Reference</th><th>Year</th><th>TC/SC</th><th>Terms</th><th>PDF</th></tr></thead>
      <tbody>
        <tr v-for="p in filtered" :key="p.id">
          <td><code>{{ p.id }}</code></td>
          <td><SLink :to="`/publications/${p.id}/`">{{ p.reference || p.id }}</SLink></td>
          <td class="num">{{ (p.id || '').match(/(\d{4})/)?.[1] || "—" }}</td>
          <td>{{ p.tc_sc || "—" }}</td>
          <td class="num">{{ termCount(p.id, onlyEdition) }}</td>
          <td><a v-if="p.link" class="external" :href="p.link">PDF ↗</a></td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
