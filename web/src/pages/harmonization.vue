<script setup lang="ts">
import harmonization from "@/data/harmonization.json";
function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
function distinctDefs(pubs: any[]) { return new Set(pubs.map(p => (p.definition || "").trim()).filter(Boolean)).size; }
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Harmonisation</span></div>
    <h1>Harmonisation worklist</h1>
    <p class="lede">Every term cited by ≥ 2 distinct OIML publications. Core TC 1 worklist for validating 202X.</p>
  </div>
  <section class="card">
    <table>
      <thead><tr><th>#</th><th>Term</th><th>VIM</th><th>Inst.</th><th>Defs</th></tr></thead>
      <tbody>
        <tr v-for="(t, i) in (harmonization as any[]).slice(0, 200)" :key="t.slug">
          <td class="num">{{ i + 1 }}</td>
          <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
          <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
          <td class="num">{{ t.publications.length }}</td>
          <td class="num">{{ distinctDefs(t.publications) }}</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
