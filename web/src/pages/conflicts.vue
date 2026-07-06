<script setup lang="ts">
import conflictsData from "@/data/conflicts.json";
import { slugifyPubId } from "@/composables/useSuggestedActions";

const rawByEdition = (conflictsData as any).raw || {};
const editions = Object.keys(rawByEdition).sort();
const totalCount = Object.values(rawByEdition).flat().length;

function slugify(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>ID Conflicts</span></div>
    <h1>ID conflicts in G 18</h1>
    <div class="admonition warn" style="margin:0.8em 0">
      <strong>TC 1 internal use.</strong> ID conflicts are numbering errors that TC 1
      must resolve by formally reallocating G 18 numbers in the 202X revision.
      Other audiences do not need to act on these.
    </div>
    <p class="lede">
      A single G 18 identifier assigned to two semantically <em>different</em> concepts.
      These are distinct from
      <SLink to="/harmonization/">definition conflicts</SLink>,
      where the <em>same</em> concept has divergent definitions across publications.
    </p>
  </div>

  <section class="card">
    <h2>What is an ID conflict?</h2>
    <p>
      An ID conflict occurs when the source publication reuses one G 18 number
      for two unrelated concepts — a numbering error, not a harmonisation
      issue. In the 2010 edition these were patched in the dataset with an
      <code>a</code>/<code>b</code> suffix split (e.g. <code>00474a</code>
      vs <code>00474b</code>); TC 1 should formally reallocate the numbers
      in the 202X revision.
    </p>
    <p v-if="!totalCount" class="muted">
      No ID conflicts detected in any edition. ✓
    </p>
  </section>

  <section v-for="ed in editions" :key="ed" class="card">
    <h2>{{ ed }} <span class="muted">({{ rawByEdition[ed].length }} conflicting IDs)</span></h2>
    <div class="table-scroll">
      <table>
      <thead><tr><th style="width:7em">ID</th><th>Distinct concepts sharing the ID</th></tr></thead>
      <tbody>
        <tr v-for="c in rawByEdition[ed]" :key="c.id">
          <td><code>{{ c.id }}</code></td>
          <td>
            <div v-for="con in c.concepts" :key="con.designation + con.source" class="conflict-concept">
              <SLink :to="`/terms/${slugify(con.designation)}/`"><strong>{{ con.designation }}</strong></SLink>
              <span class="muted"> — <SLink v-if="con.source" :to="`/publications/${slugifyPubId(con.source)}/`">{{ con.source }}</SLink> <code>{{ con.raw_id }}</code></span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>

  <section class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-amber-soft);">
    <h2>How TC 1 should resolve these</h2>
    <ul>
      <li>For each conflicting ID, decide which concept keeps the number and assign a new G 18 ID to the other.</li>
      <li>Update the <code>identifier</code> field on the displaced concept in <code>oimlsmart/vocab datasets/g18-202X/</code>.</li>
      <li>The 2010 dataset uses the <code>&lt;id&gt;a</code>/<code>&lt;id&gt;b</code> suffix convention (e.g. <code>00474a</code> / <code>00474b</code>) to disambiguate.</li>
      <li>The 202X dataset uses a publication-derived suffix (<code>&lt;id&gt;-RXXX-N</code>, e.g. <code>02344-R049-1</code> / <code>02344-R099-1</code>) — the underlying G 18 number is still shared and needs editorial reallocation.</li>
      <li>Both styles are dataset workarounds, not published conventions.</li>
      <li>For the related problem of one concept cited under many IDs, see the <SLink to="/harmonization/">harmonisation worklist</SLink>.</li>
    </ul>
  </section>
</template>
