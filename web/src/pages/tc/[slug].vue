<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import tcData from "@/data/tc.json";
import terms from "@/data/terms.json";
const route = useRoute();
function slug(name: string) { return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }
const tcName = computed(() => (tcData as string[]).find(t => slug(t) === route.params.slug));
const tcTerms = computed(() => !tcName.value ? [] : (terms as any[]).filter(t => t.publications.some((p: any) => p.tc_sc === tcName.value)));
function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
</script>
<template>
  <div v-if="!tcName" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/tc/">TC</SLink> / <span>{{ tcName }}</span></div>
      <h1>{{ tcName }}</h1>
    </div>
    <section class="card">
      <div class="table-scroll">
      <table>
        <thead><tr><th>Term</th><th>VIM</th><th>Instances</th></tr></thead>
        <tbody>
          <tr v-for="t in tcTerms" :key="t.slug">
            <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td class="num">{{ t.publications.filter((p: any) => p.tc_sc === tcName).length }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    </section>
  </template>
</template>
