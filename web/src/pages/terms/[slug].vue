<script setup lang="ts">
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import termBySlug from "@/data/term-by-slug.json";
import { useVocabularyEdition } from "@/composables/useVocabularyEdition";

const route = useRoute();
const { label, confidenceClass, isCurrent, isSuperseded, latestLabel, vocabUrl, vocab, role } = useVocabularyEdition();

const term = computed(() => (termBySlug as any)[route.params.slug as string]);
const enabledEditions = ref<Set<string>>(new Set());
const onlyDivergent = ref(false);

function initEditions() {
  if (term.value?.editions_present) enabledEditions.value = new Set(term.value.editions_present);
}
initEditions();

function toggleEdition(ed: string) {
  if (enabledEditions.value.has(ed)) enabledEditions.value.delete(ed);
  else enabledEditions.value.add(ed);
  enabledEditions.value = new Set(enabledEditions.value);
}

function rowVisible(p: any) {
  if (!enabledEditions.value.has(p.edition)) return false;
  if (onlyDivergent.value && distinctDefs.value.length > 1) {
    return p.definition?.trim() !== distinctDefs.value[0];
  }
  return true;
}

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }

const distinctDefs = computed(() => {
  if (!term.value) return [];
  return Array.from(new Set(term.value.publications.map((p: any) => (p.definition || "").trim()).filter(Boolean)));
});
const consistencyCounts = computed(() => {
  if (!term.value) return { ok: 0, partial: 0, ko: 0, pending: 0 } as Record<string, number>;
  const c: Record<string, number> = { ok: 0, partial: 0, ko: 0, pending: 0 };
  for (const p of term.value.publications) c[p.consistency || "pending"] = (c[p.consistency || "pending"] || 0) + 1;
  return c;
});
const matchStatus = computed(() => {
  if (!term.value) return null;
  if (term.value.kind === "undefined") return { key: "notinviml", label: "Not in VIM/VIML" };
  const urn = term.value.official_concept?.source;
  if (!urn) return { key: "notinviml", label: "Not in VIM/VIML" };
  const r = role(urn);
  if (r === "current") return { key: "full", label: `Full match — ${label(urn)}` };
  if (r) return { key: "outdated", label: `Outdated — ${label(urn)}` };
  return null;
});
const actions = computed(() => {
  if (!term.value) return [];
  const a: any[] = [];
  const oc = term.value.official_concept;
  const lc = term.value.latest_check;
  if (oc && oc.source && isSuperseded(oc.source) && lc) {
    if (lc.found) {
      a.push({ priority: "info", text: `✓ This term IS in ${lc.latest_label} (concept #${lc.concept_id}). Definition may differ from ${oc.edition_label}.`, link: lc.url, label: `View ${lc.latest_label} entry` });
    } else {
      a.push({ priority: "high", text: `✗ This term is NOT in ${lc.latest_label}. It may have been removed, renamed, or superseded by a different concept.` });
    }
  }
  if (term.value.kind === "undefined") {
    a.push({ priority: "high", text: "No authoritative definition in VIM or VIML." });
  }
  if (distinctDefs.value.length > 1) {
    a.push({ priority: "medium", text: `${distinctDefs.value.length} distinct definitions — harmonise.` });
  }
  const cc = consistencyCounts.value;
  if (cc.ko > 0) a.push({ priority: "high", text: `${cc.ko} diverge (ko).` });
  if (cc.partial > 0) a.push({ priority: "low", text: `${cc.partial} partially diverge.` });
  return a;
});
</script>

<template>
  <div v-if="!term" class="card"><p>Term not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><RouterLink to="/">Registry</RouterLink> / <RouterLink to="/terms/">Terms</RouterLink> / <span>{{ term.name }}</span></div>
      <h1>{{ term.name }}</h1>
      <p class="lede">
        <span :class="['kind', `kind-${term.kind}`]">{{ kindLabel(term.kind) }}</span>
        <span v-if="matchStatus" :class="['match-status', `match-status-${matchStatus.key}`]">{{ matchStatus.label }}</span>
        G 18 #{{ term.identifier }} · {{ term.publications.length }} instances
      </p>
    </div>

    <section class="card" v-if="term.official_concept && term.kind !== 'undefined'">
      <h2>Authoritative definition</h2>
      <div :class="['authority-defn', confidenceClass(term.official_concept.source)]">
        <span :class="confidenceClass(term.official_concept.source)">
          {{ term.official_concept.edition_label || term.official_concept.source }}
          <span v-if="isCurrent(term.official_concept.source)" class="viml-latest-badge">Latest</span>
        </span>
        · concept <strong>#{{ term.official_concept.id }}</strong>
        <a v-if="term.official_concept.url" class="external" :href="term.official_concept.url">view ↗</a>
        <p v-if="term.official_concept.definition_text" class="authority-defn-body">{{ term.official_concept.definition_text }}</p>
      </div>
      <div v-if="isSuperseded(term.official_concept.source)" class="admonition warn">
        <strong>Outdated:</strong> Cites {{ label(term.official_concept.source) }}. Latest: {{ latestLabel(term.official_concept.source) }}.
      </div>
      <ul v-if="term.related?.length" style="list-style:none;padding:0;margin-top:0.5em">
        <li v-for="(edge, i) in term.related" :key="i" style="margin-bottom:0.3em">
          <span :class="confidenceClass(edge.ref?.source)">{{ edge.ref?.edition_label || edge.ref?.source }}</span>
          · #{{ edge.ref?.id }}
          <div v-if="edge.ref?.definition_text" class="authority-defn-body" style="font-size:0.92em">{{ edge.ref.definition_text }}</div>
        </li>
      </ul>
    </section>

    <section v-if="actions.length" class="card">
      <h2>Suggested actions</h2>
      <ol class="actions-list">
        <li v-for="(a, i) in actions" :key="i">
          <span :class="['action-pill', `action-pill-${a.priority}`]">{{ a.priority.toUpperCase() }}</span>
          {{ a.text }}
        </li>
      </ol>
    </section>

    <section class="card">
      <div class="card-head">
        <h2>Publication instances</h2>
        <div style="display:flex;gap:1em;align-items:center;flex-wrap:wrap">
          <label><input type="checkbox" v-model="onlyDivergent" /> Divergent only</label>
          <span v-for="ed in term.editions_present" :key="ed">
            <label><input type="checkbox" :checked="enabledEditions.has(ed)" @change="toggleEdition(ed)" />
              <span :class="['edition-pill', `edition-${ed.toLowerCase()}`]">{{ ed }}</span>
            </label>
          </span>
        </div>
      </div>
      <table>
        <thead><tr><th>Ed.</th><th>Year</th><th>Publication</th><th>Clause</th><th>Definition</th><th>Consistency</th></tr></thead>
        <tbody>
          <tr v-for="p in term.publications" :key="p.g18_entry" v-show="rowVisible(p)" :class="{ 'row-divergent': distinctDefs.length > 1 && p.definition?.trim() !== distinctDefs[0] }">
            <td><span :class="['edition-pill', `edition-${p.edition?.toLowerCase()}`]">{{ p.edition }}</span></td>
            <td class="num">{{ p.year }}</td>
            <td><RouterLink :to="`/publications/${p.publication_id}/`">{{ p.publication }}</RouterLink><div class="muted" style="font-size:0.75em">#{{ p.g18_entry }}</div></td>
            <td class="num">{{ p.clause }}</td>
            <td style="max-width:540px"><div style="white-space:pre-wrap">{{ p.definition }}</div></td>
            <td><span :class="['badge', `badge-${p.consistency || 'pending'}`]">{{ p.consistency || "pending" }}</span></td>
          </tr>
        </tbody>
      </table>
    </section>
  </template>
</template>
