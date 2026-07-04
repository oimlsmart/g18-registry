<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import publications from "@/data/publications.json";
import terms from "@/data/terms.json";
const route = useRoute();
const pubId = computed(() => route.params.slug as string);
const pub = computed(() => (publications as any[]).find(p => p.id === pubId.value));
const pubTerms = computed(() => (terms as any[]).filter(t => t.publications.some((p: any) => p.publication_id === pubId.value)));
function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }

// Provenance breakdown: how many of this pub's term adoptions are
// verbatim quotes / modified / OIML-original — TC1 cares about the
// modified ones (editorial decisions to review).
const provenanceSummary = computed(() => {
  const counts = { identical: 0, modified: 0, authoritative: 0, derived: 0, similar: 0, other: 0 };
  const modifiedTerms: any[] = [];
  for (const t of pubTerms.value) {
    const p = t.publications.find((pp: any) => pp.publication_id === pubId.value);
    const rel = p?.source?.relationship;
    if (rel && counts.hasOwnProperty(rel)) (counts as any)[rel] += 1;
    else counts.other += 1;
    if (rel === "modified") {
      modifiedTerms.push({ name: t.name, slug: t.slug, modification: p.source.modification, ref_source: p.source.ref_source });
    }
  }
  return { counts, modifiedTerms };
});
</script>
<template>
  <div v-if="!pub" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/publications/">Publications</SLink> / <span>{{ pub.reference || pub.id }}</span></div>
      <h1>{{ pub.reference || pub.id }}</h1>
      <p class="lede">
        {{ pubTerms.length }} terms
        <span v-if="pub.tc_sc"> · TC/SC: {{ pub.tc_sc }}</span>
        <span v-if="pub.year"> · {{ pub.year }}</span>
        <a v-if="pub.link" class="external" :href="pub.link" style="margin-left:0.6em">PDF ↗</a>
      </p>
    </div>

    <section class="card" v-if="provenanceSummary.modifiedTerms.length || provenanceSummary.counts.identical || provenanceSummary.counts.modified">
      <h2>Adoption provenance</h2>
      <p class="lede">Where this publication's term definitions come from.</p>
      <div class="prov-grid">
        <div class="prov-tile">
          <div class="prov-tile-num">{{ provenanceSummary.counts.identical }}</div>
          <div class="prov-tile-label">Verbatim VIM/VIML quotes</div>
        </div>
        <div class="prov-tile prov-tile-warn">
          <div class="prov-tile-num">{{ provenanceSummary.counts.modified }}</div>
          <div class="prov-tile-label">Modified adoptions (need TC1 review)</div>
        </div>
        <div class="prov-tile">
          <div class="prov-tile-num">{{ provenanceSummary.counts.authoritative + provenanceSummary.counts.other }}</div>
          <div class="prov-tile-label">OIML-original</div>
        </div>
      </div>
      <details v-if="provenanceSummary.modifiedTerms.length" style="margin-top:0.7em">
        <summary>Modified adoptions ({{ provenanceSummary.modifiedTerms.length }})</summary>
        <ul style="margin:0.5em 0 0;padding-left:1.2em;font-size:0.9em">
          <li v-for="(m, i) in provenanceSummary.modifiedTerms" :key="i" style="margin-bottom:0.5em">
            <SLink :to="`/terms/${m.slug}/`">{{ m.name }}</SLink>
            <span class="muted"> — from {{ m.ref_source }}</span>
            <div>{{ m.modification }}</div>
          </li>
        </ul>
      </details>
    </section>

    <section class="card">
      <h2>Terms ({{ pubTerms.length }})</h2>
      <div class="table-scroll">
      <table>
        <thead><tr><th>Term</th><th>VIM</th><th>Source</th><th>Definition</th></tr></thead>
        <tbody>
          <tr v-for="t in pubTerms" :key="t.slug">
            <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td>
              <span v-if="t.publications.find((p: any) => p.publication_id === pubId)?.source"
                    :class="['rel-pill', `rel-${t.publications.find((p: any) => p.publication_id === pubId).source.relationship}`]"
                    :title="t.publications.find((p: any) => p.publication_id === pubId).source.modification || ''">
                {{ t.publications.find((p: any) => p.publication_id === pubId).source.relationship }}
              </span>
              <span v-else class="muted">OIML</span>
            </td>
            <td style="max-width:540px">{{ t.publications.find((p: any) => p.publication_id === pubId)?.definition }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    </section>
  </template>
</template>

<style scoped>
.prov-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.7em; margin: 0.5em 0; }
.prov-tile { padding: 0.8em 1em; background: #f0f7ff; border-radius: 5px; border-left: 3px solid var(--accent); }
.prov-tile-warn { background: #fffbeb; border-left-color: var(--oiml-amber-deep); }
.prov-tile-num { font-size: 1.8em; font-weight: 700; color: var(--accent); line-height: 1; }
.prov-tile-warn .prov-tile-num { color: var(--oiml-amber-deep); }
.prov-tile-label { font-size: 0.85em; color: var(--ink-soft); margin-top: 0.2em; }
.rel-pill { display: inline-block; padding: 0.1em 0.5em; border-radius: 3px; font-size: 0.74em; font-weight: 600; text-transform: uppercase; }
.rel-identical { background: #dcfce7; color: var(--green); }
.rel-modified  { background: #fef3c7; color: var(--oiml-amber-deep); }
.rel-authoritative { background: #dbeafe; color: #1e3a8a; }
.rel-derived, .rel-similar { background: #eef0f3; color: var(--ink-muted); }
@media (max-width: 600px) { .prov-grid { grid-template-columns: 1fr; } }
</style>
