<script setup lang="ts">
import { ref, computed } from "vue";
import publications from "@/data/publications.json";
import terms from "@/data/terms.json";

const onlyEdition = ref("");
const sortByProblems = ref(false);

const filtered = computed(() => {
  let pubs = publications as any[];
  if (onlyEdition.value) {
    const pubIds = new Set<string>();
    for (const t of terms as any[]) {
      if (t.editions_present?.includes(onlyEdition.value)) {
        for (const p of t.publications || []) if (p.publication_id) pubIds.add(p.publication_id);
      }
    }
    pubs = pubs.filter(p => pubIds.has(p.id));
  }
  if (sortByProblems.value) {
    pubs = [...pubs].sort((a, b) => problemCount(b.id) - problemCount(a.id) || (b.year || 0) - (a.year || 0));
  }
  return pubs;
});

function termCount(pubId: string, ed: string) {
  return (terms as any[]).filter(t => t.publications.some((p: any) => p.publication_id === pubId && (!ed || t.editions_present?.includes(ed)))).length;
}

// Terms under a publication that are "problematic": divergent definitions
// (≥2 distinct defs), outdated VIM refs, modified adoptions, or ID-conflicting.
function problemTerms(pubId: string): any[] {
  const out: any[] = [];
  for (const t of terms as any[]) {
    const pubs = (t.publications || []).filter((p: any) => p.publication_id === pubId);
    if (pubs.length === 0) continue;
    const dd = new Set(t.publications.map((p: any) => (p.definition || "").trim()).filter(Boolean)).size;
    const lc = t.latest_check;
    const modifiedCount = pubs.filter((p: any) => p.source?.relationship === "modified").length;
    const reasons: string[] = [];
    if (dd >= 2) reasons.push(`${dd} distinct defs`);
    if (lc && !lc.found) reasons.push(`cites superseded edition`);
    if (lc && lc.found && t.official_concept && lc.concept_id !== t.official_concept.id) reasons.push(`concept id mismatch`);
    if (modifiedCount > 0) reasons.push(`${modifiedCount} modified adoption${modifiedCount > 1 ? "s" : ""}`);
    if (reasons.length) out.push({ name: t.name, slug: t.slug, reasons });
  }
  return out;
}

function problemCount(pubId: string): number {
  return problemTerms(pubId).length;
}
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Publications</span></div>
    <h1>Publications</h1>
    <p class="lede">{{ (publications as any[]).length }} publications.</p>
  </div>
  <section class="card">
    <form class="filter-form" @submit.prevent>
      <select v-model="onlyEdition"><option value="">All editions</option><option value="2010">2010 only</option><option value="202X">202X only</option></select>
      <label class="sort-toggle-label">
        <input type="checkbox" v-model="sortByProblems" />
        Sort by problematic terms first
      </label>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>
    <table>
      <thead><tr><th>ID</th><th>Reference</th><th>Year</th><th>TC/SC</th><th>Terms</th><th v-if="sortByProblems">Problematic</th><th>PDF</th></tr></thead>
      <tbody>
        <tr v-for="p in filtered" :key="p.id">
          <td><code>{{ p.id }}</code></td>
          <td><SLink :to="`/publications/${p.id}/`">{{ p.reference || p.id }}</SLink></td>
          <td class="num">{{ (p.id || '').match(/(\d{4})/)?.[1] || "—" }}</td>
          <td>{{ p.tc_sc || "—" }}</td>
          <td class="num">{{ termCount(p.id, onlyEdition) }}</td>
          <td v-if="sortByProblems" class="num">
            <span v-if="problemCount(p.id)" class="problem-count">{{ problemCount(p.id) }}</span>
            <span v-else class="muted">—</span>
          </td>
          <td><a v-if="p.link" class="external" :href="p.link">PDF ↗</a></td>
        </tr>
      </tbody>
    </table>

    <section v-if="sortByProblems" class="pub-problem-detail">
      <h2>Problematic terms per publication</h2>
      <details v-for="p in filtered.filter(x => problemCount(x.id) > 0)" :key="p.id" class="pub-problem-block">
        <summary>
          <strong>{{ p.reference || p.id }}</strong>
          <span class="muted"> — {{ problemCount(p.id) }} term(s)</span>
        </summary>
        <ul>
          <li v-for="pt in problemTerms(p.id)" :key="pt.slug">
            <SLink :to="`/terms/${pt.slug}/`">{{ pt.name }}</SLink>
            <span class="muted"> — {{ pt.reasons.join('; ') }}</span>
          </li>
        </ul>
      </details>
    </section>
  </section>
</template>
