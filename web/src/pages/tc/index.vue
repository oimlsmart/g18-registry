<script setup lang="ts">
import tcData from "@/data/tc.json";
import terms from "@/data/terms.json";
function termCount(name: string) { return (terms as any[]).filter(t => t.publications.some((p: any) => p.tc_sc === name)).length; }
function pubCount(name: string) { return new Set((terms as any[]).flatMap(t => t.publications).filter((p: any) => p.tc_sc === name).map((p: any) => p.publication_id)).size; }
function slug(name: string) { return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>TC / SC</span></div>
    <h1>Technical Committees</h1>
  </div>
  <section class="card">
    <table>
      <thead><tr><th>TC / SC</th><th>Publications</th><th>Terms</th></tr></thead>
      <tbody>
        <tr v-for="t in (tcData as string[])" :key="t">
          <td><SLink :to="`/tc/${slug(t)}/`">{{ t }}</SLink></td>
          <td class="num">{{ pubCount(t) }}</td>
          <td class="num">{{ termCount(t) }}</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
