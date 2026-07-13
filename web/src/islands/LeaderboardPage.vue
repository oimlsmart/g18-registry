<script setup lang="ts">
import leaderboardData from "@/data/leaderboard-data.json";
import SLink from "@/components/SLink.vue";

const top = (leaderboardData as any[])
  .filter(t => t.pub_count > 1)
  .sort((a, b) => {
    if (b.distinct_defs !== a.distinct_defs) return b.distinct_defs - a.distinct_defs;
    if (b.pub_count !== a.pub_count) return b.pub_count - a.pub_count;
    return (a.name || "").localeCompare(b.name || "");
  })
  .slice(0, 20);
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Divergence</span></div>
    <h1>Divergence leaderboard</h1>
  </div>
  <section class="card">
    <div class="table-scroll">
      <table>
      <thead><tr><th>#</th><th>Term</th><th>Instances</th><th>Distinct defs</th></tr></thead>
      <tbody>
        <tr v-for="(t, i) in top" :key="t.slug">
          <td class="num">{{ i + 1 }}</td>
          <td><SLink :to="`/concepts/${t.slug}/`">{{ t.name }}</SLink></td>
          <td class="num">{{ t.pub_count }}</td>
          <td class="num"><span class="divergence-count">{{ t.distinct_defs }}</span></td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>
</template>
