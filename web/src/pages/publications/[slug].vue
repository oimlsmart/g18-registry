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
</script>
<template>
  <div v-if="!pub" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/publications/">Publications</SLink> / <span>{{ pub.reference || pub.id }}</span></div>
      <h1>{{ pub.reference || pub.id }}</h1>
    </div>
    <section class="card">
      <h2>Terms ({{ pubTerms.length }})</h2>
      <table>
        <thead><tr><th>Term</th><th>VIM</th><th>Definition</th></tr></thead>
        <tbody>
          <tr v-for="t in pubTerms" :key="t.slug">
            <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td style="max-width:540px">{{ t.publications.find((p: any) => p.publication_id === pubId)?.definition }}</td>
          </tr>
        </tbody>
      </table>
    </section>
  </template>
</template>
