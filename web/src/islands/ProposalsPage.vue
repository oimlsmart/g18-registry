<script setup lang="ts">
import { ref, computed, nextTick } from "vue";
import { useVocabGaps, vocabGaps, type VocabGap } from "@/composables/useVocabGaps";
import { usePagination } from "@/composables/usePagination";
import {
  composeIssueBody,
  composeIssueUrl,
  composeIssueTitle,
  targetLabel,
  TARGET_CATEGORIES,
  categoryForTarget,
  type ProposalTarget,
  type ProposalDraft,
} from "@/composables/useGapProposal";
import SLink from "@/components/SLink.vue";
import PaginationControls from "@/components/PaginationControls.vue";

const { search, scope, tcFilter, allTCs, filtered } = useVocabGaps();
const pagination = usePagination(filtered, {
  pageSize: 50,
  dep: () => `${scope.value}|${tcFilter.value}|${search.value}`,
});

// Auto-open proposal modal when arriving via ?term=<slug> link
if (typeof window !== "undefined") {
  const params = new URLSearchParams(window.location.search);
  const termSlug = params.get("term");
  if (termSlug) {
    const gap = vocabGaps.find(g => g.slug === termSlug);
    if (gap) {
      nextTick(() => openProposal(gap));
    }
  }
}

// Currently-open proposal form (one at a time).
const openGap = ref<VocabGap | null>(null);
const proposalTarget = ref<ProposalTarget>("V3");
const proposalRationale = ref("");
const proposalAuthor = ref("");
const generating = ref(false);
const issueUrl = ref<string | null>(null);

function openProposal(g: VocabGap) {
  openGap.value = g;
  // Default target: if any near-miss exists, lean toward reconcile (V1/V2).
  // Otherwise default to V 3 (specific term).
  const nm = g.near_misses.viml || g.near_misses.vim;
  proposalTarget.value = nm ? (g.near_misses.viml ? "V1" : "V2") : "V3";
  proposalRationale.value = nm
    ? `The G 18 term "${g.name}" appears related to ${nm.latest_label} "${nm.designation}" (concept ${nm.concept_id}). Decide: re-link to ${nm.latest_label}, document as a deliberate OIML-specific variant (candidate for V 3), or confirm OIML as authoritative.`
    : `The G 18 term "${g.name}" has no VIM/VIML equivalent. It appears to be a specific term used across ${g.publications.length} OIML publication(s). Propose for inclusion in V 3 (specific terms).`;
  issueUrl.value = null;
}

function closeProposal() {
  openGap.value = null;
  issueUrl.value = null;
}

async function submitProposal() {
  if (!openGap.value) return;
  generating.value = true;
  try {
    const draft: ProposalDraft = {
      gap: openGap.value,
      target: proposalTarget.value,
      rationale: proposalRationale.value,
      author: proposalAuthor.value || undefined,
    };
    const body = await composeIssueBody(draft);
    issueUrl.value = composeIssueUrl(draft, body);
    if (typeof window !== "undefined") {
      window.open(issueUrl.value, "_blank", "noopener");
    }
  } finally {
    generating.value = false;
  }
}

// Scope filter now leads with conceptual categories (V 3 candidates /
// V 1/V 2 candidates / All) instead of abstract near-miss labels.
const scopeButtons: { val: typeof scope.value; concept: string; target: string; count: number }[] = [
  {
    val: "no-match",
    concept: "V 3 candidates",
    target: "no VIM/VIML near-miss — likely specific terms",
    count: vocabGaps.filter(g => !g.near_misses.vim && !g.near_misses.viml).length,
  },
  {
    val: "any-match",
    concept: "V 1 / V 2 candidates",
    target: "has VIM/VIML near-miss — reconcile or relink",
    count: vocabGaps.filter(g => g.near_misses.vim || g.near_misses.viml).length,
  },
  {
    val: "all",
    concept: "All",
    target: "every OIML-original term",
    count: vocabGaps.length,
  },
];

const issueTitlePreview = computed(() =>
  openGap.value ? composeIssueTitle({ gap: openGap.value, target: proposalTarget.value, rationale: "" }) : ""
);

function nearMissBadgeClass(nm: any): string {
  if (!nm) return "muted";
  return nm.match_type === "exact" ? "badge badge-ok" : "badge badge-partial";
}
function nearMissText(nm: any): string {
  if (!nm) return "—";
  return nm.match_type === "exact" ? nm.designation : `${nm.designation} (${nm.similarity})`;
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Vocabulary gaps</span></div>
    <h1>Vocabulary gap analysis</h1>
    <p class="lede">
      G 18 terms with no authoritative VIM/VIML source. For each, decide:
      propose for <strong>VIM (V 2)</strong> (general metrology concept),
      <strong>VIML (V 1)</strong> (legal metrology concept), or
      <strong>V 3</strong> (specific terms like "load cell" — proposed new vocabulary).
    </p>
  </div>

  <!-- How to propose: prerequisites and steps -->
  <div class="proposal-howto">
    <div class="proposal-howto-head">How to propose</div>
    <ol class="proposal-howto-steps">
      <li>
        <strong>Prerequisite.</strong>
        You need a GitHub account and TC 1 (Vocabulary) member access to the
        <a href="https://github.com/oimlsmart" target="_blank" rel="noopener">OIML GitHub organization</a>.
        No access? Contact the TC 1 secretariat.
      </li>
      <li>
        <strong>Find</strong> a term below that lacks a VIM/VIML definition.
        Use the scope filter to focus on V 3 candidates (no near-miss) or
        V 1/V 2 candidates (has a near-miss).
      </li>
      <li>
        <strong>Propose</strong> by clicking the "Propose" button on a term.
        Choose its target — <strong>V 1 / V 2</strong> adds the term to the
        next edition of an existing vocabulary (VIM or VIML); <strong>V 3</strong>
        proposes a brand-new vocabulary for specific terms.
        Add your rationale.
      </li>
      <li>
        <strong>Submit.</strong>
        A pre-filled GitHub issue opens with a structured YAML payload and
        checksum. Review and submit it for TC 1 consideration.
      </li>
    </ol>
  </div>

  <!-- Sticky scope filter — leads with conceptual categories -->
  <div class="page-filter" role="region" aria-label="Scope filter">
    <span class="page-filter-label">Scope</span>
    <div class="page-filter-controls">
      <button v-for="b in scopeButtons" :key="b.val"
              type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': scope === b.val }]"
              @click="scope = b.val">
        <span class="page-filter-btn-title">{{ b.concept }}</span>
        <span class="page-filter-btn-meta">{{ b.count }} terms · {{ b.target }}</span>
      </button>
    </div>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search term…" />
      <select v-model="tcFilter">
        <option value="">All TC/SCs</option>
        <option v-for="tc in allTCs" :key="tc" :value="tc">{{ tc }}</option>
      </select>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>

    <!-- Desktop table — only the Propose action + minimal context columns
         are always shown. Definition is a hint column (hidden on narrow
         viewports) so the Propose button is always reachable. -->
    <div class="table-scroll table-only-desktop">
      <table>
        <thead>
          <tr>
            <th>Term</th>
            <th>Near-miss</th>
            <th class="num">Pubs</th>
            <th class="vocab-gaps-def">Definition (first)</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="g in pagination.visible.value" :key="g.slug">
            <td class="term-cell"><SLink :to="`/terms/${g.slug}/`">{{ g.name }}</SLink></td>
            <td>
              <div class="vocab-gaps-nm">
                <span v-if="g.near_misses.vim || g.near_misses.viml" class="vocab-gaps-nm-badges">
                  <a v-if="g.near_misses.viml" :href="g.near_misses.viml.url" target="_blank" rel="noopener" :class="nearMissBadgeClass(g.near_misses.viml)" :title="(g.near_misses.viml.designation || '') + (g.near_misses.viml.match_type === 'exact' ? ' (exact)' : ` (sim ${g.near_misses.viml.similarity})`) + ' — click to view full definition on vocab site'">VIML: {{ nearMissText(g.near_misses.viml) }}</a>
                  <a v-if="g.near_misses.vim" :href="g.near_misses.vim.url" target="_blank" rel="noopener" :class="nearMissBadgeClass(g.near_misses.vim)" :title="(g.near_misses.vim.designation || '') + (g.near_misses.vim.match_type === 'exact' ? ' (exact)' : ` (sim ${g.near_misses.vim.similarity})`) + ' — click to view full definition on vocab site'">VIM: {{ nearMissText(g.near_misses.vim) }}</a>
                </span>
                <span v-else class="muted">no near-miss</span>
              </div>
            </td>
            <td class="num">{{ g.publications.length }}</td>
            <td class="vocab-gaps-def"><span class="muted" style="font-size:0.88em">{{ (g.definitions[0] || '—').slice(0, 80) }}{{ (g.definitions[0] || '').length > 80 ? '…' : '' }}</span></td>
            <td><button type="button" class="sort-btn sort-btn-active" @click="openProposal(g)">Propose</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mobile cards -->
    <ul class="gap-cards table-only-mobile">
      <li v-for="g in pagination.visible.value" :key="g.slug" class="gap-card">
        <div class="gap-card-head">
          <SLink :to="`/terms/${g.slug}/`" class="term-card-name">{{ g.name }}</SLink>
          <span class="muted">{{ g.publications.length }} pubs</span>
        </div>
        <div class="gap-card-meta">
          <div><span class="muted">VIM:</span> <a v-if="g.near_misses.vim" :href="g.near_misses.vim.url" target="_blank" rel="noopener" :class="nearMissBadgeClass(g.near_misses.vim)">{{ nearMissText(g.near_misses.vim) }}</a><span v-else class="muted">—</span></div>
          <div><span class="muted">VIML:</span> <a v-if="g.near_misses.viml" :href="g.near_misses.viml.url" target="_blank" rel="noopener" :class="nearMissBadgeClass(g.near_misses.viml)">{{ nearMissText(g.near_misses.viml) }}</a><span v-else class="muted">—</span></div>
        </div>
        <div class="gap-card-def" v-if="g.definitions[0]">{{ g.definitions[0].slice(0, 140) }}{{ g.definitions[0].length > 140 ? '…' : '' }}</div>
        <button type="button" class="sort-btn sort-btn-active" @click="openProposal(g)">Propose</button>
      </li>
    </ul>

    <PaginationControls :pagination="pagination" noun="terms" />
  </section>

  <!-- Proposal modal -->
  <div v-if="openGap" class="modal-backdrop" @click.self="closeProposal">
    <div class="modal">
      <div class="modal-head">
        <h2>Propose vocabulary placement</h2>
        <button type="button" class="modal-close" @click="closeProposal" aria-label="Close">×</button>
      </div>
      <div class="modal-body">
        <p class="modal-term">
          <strong>{{ openGap.name }}</strong>
          <span class="muted"> · {{ openGap.publications.length }} pubs</span>
        </p>

        <fieldset class="proposal-target">
          <legend>Classify this term</legend>
          <label v-for="cat in TARGET_CATEGORIES" :key="cat.code" :class="['proposal-target-option', { 'proposal-target-selected': proposalTarget === cat.code }]">
            <input type="radio" name="proposal-target" :value="cat.code" v-model="proposalTarget" />
            <span class="proposal-target-text">
              <span class="proposal-target-concept">{{ cat.concept }}</span>
              <span class="proposal-target-arrow">→</span>
              <span class="proposal-target-vocab">{{ cat.target }}</span>
              <span class="proposal-target-examples">{{ cat.examples }}</span>
            </span>
          </label>
        </fieldset>

        <label class="proposal-field">
          <span>Rationale</span>
          <textarea v-model="proposalRationale" rows="6"></textarea>
        </label>

        <label class="proposal-field">
          <span>Your name (optional, for the proposed_by field)</span>
          <input v-model="proposalAuthor" type="text" placeholder="e.g. Jane Doe" />
        </label>

        <p class="modal-issue-preview">
          <strong>Issue title:</strong> {{ issueTitlePreview }}
        </p>

        <p v-if="issueUrl" class="modal-success">
          Opened in a new tab. If it didn't open,
          <a :href="issueUrl" target="_blank" rel="noopener">click here</a>.
        </p>
      </div>
      <div class="modal-foot">
        <button type="button" class="sort-btn" @click="closeProposal">Cancel</button>
        <button type="button" class="sort-btn sort-btn-active" :disabled="generating" @click="submitProposal">
          {{ generating ? "Composing…" : "Open GitHub issue" }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.proposal-howto {
  background: var(--color-accent-tint);
  border: 1px solid var(--color-accent-soft);
  border-radius: 6px;
  padding: 1em 1.2em;
  margin-bottom: 1.2em;
}
.proposal-howto-head {
  font-size: 0.82rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--color-accent);
  margin-bottom: 0.5em;
}
.proposal-howto-steps {
  margin: 0;
  padding-left: 1.5em;
  display: flex;
  flex-direction: column;
  gap: 0.4em;
}
.proposal-howto-steps li {
  font-size: 0.86rem;
  line-height: 1.5;
  color: var(--color-ink-soft);
}
.proposal-howto-steps li strong {
  color: var(--color-ink);
}

.vocab-gaps-nm {
  display: flex;
  flex-direction: column;
  gap: 0.2em;
  font-size: 0.78rem;
}
.vocab-gaps-nm-badges {
  display: flex;
  flex-direction: column;
  gap: 0.2em;
}
.vocab-gaps-nm-badges .badge {
  font-size: 0.72rem;
  max-width: 24ch;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  text-align: left;
  text-decoration: none;
  cursor: pointer;
  transition: opacity 0.15s;
}
.vocab-gaps-nm-badges .badge:hover { opacity: 0.85; }
.vocab-gaps-def {
  max-width: 220px;
}
@media (max-width: 1100px) {
  .vocab-gaps-def { display: none; }
}
@media (max-width: 820px) {
  /* The page-filter buttons become cards on narrow viewports too; they
     can be mistaken for term content. Tighten to look like controls. */
  .page-filter-btn { min-width: 0; padding: 0.4em 0.7em; }
  .page-filter-btn-meta { font-size: 0.7rem; }
}
.gap-cards {
  list-style: none;
  margin: 0.5rem 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}
.gap-card {
  background: var(--color-paper-soft);
  border: 1px solid var(--color-rule);
  border-radius: var(--radius-card);
  padding: 0.85rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.4em;
}
.gap-card-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 0.6em;
}
.gap-card-meta {
  display: flex;
  flex-direction: column;
  gap: 0.25em;
  font-size: 0.88rem;
}
.gap-card-meta .muted {
  margin-right: 0.3em;
}
.gap-card-def {
  font-size: 0.88em;
  color: var(--color-ink-soft);
  line-height: 1.4;
}

.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(10, 22, 40, 0.55);
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}
.modal {
  background: var(--color-paper-soft);
  border-radius: var(--radius-card);
  max-width: 600px;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
  border: 1px solid var(--color-rule);
}
.modal-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--color-rule-soft);
}
.modal-head h2 {
  margin: 0;
  font-size: 1.15rem;
  border: none;
  padding: 0;
}
.modal-close {
  appearance: none;
  background: transparent;
  border: 0;
  font-size: 1.5rem;
  line-height: 1;
  cursor: pointer;
  color: var(--color-ink-muted);
  padding: 0.25em 0.5em;
}
.modal-body { padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: 0.9rem; }
.modal-term { margin: 0 0 0.4em; }
.modal-issue-preview {
  font-size: 0.88em;
  background: var(--color-paper-tint);
  padding: 0.5em 0.75em;
  border-radius: 4px;
  margin: 0;
}
.modal-success {
  font-size: 0.88em;
  color: var(--color-green);
  margin: 0;
}
.modal-foot {
  display: flex;
  justify-content: flex-end;
  gap: 0.5em;
  padding: 0.8rem 1.25rem;
  border-top: 1px solid var(--color-rule-soft);
}
.proposal-target {
  border: 1px solid var(--color-rule);
  border-radius: 4px;
  padding: 0.6em 0.9em;
  display: flex;
  flex-direction: column;
  gap: 0.4em;
}
.proposal-target legend {
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 700;
  color: var(--color-ink-muted);
  padding: 0 0.4em;
}
.proposal-target-option {
  display: flex;
  align-items: flex-start;
  gap: 0.5em;
  padding: 0.55em 0.7em;
  border: 1px solid transparent;
  border-radius: 3px;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.proposal-target-option:hover {
  background: var(--color-paper-tint);
}
.proposal-target-selected {
  background: var(--color-accent-tint);
  border-color: var(--color-accent-soft);
}
.proposal-target-option input[type="radio"] {
  margin-top: 0.35em;
}
.proposal-target-text {
  display: flex;
  flex-direction: column;
  gap: 0.1em;
  flex: 1;
}
.proposal-target-concept {
  font-family: var(--font-display);
  font-size: 1rem;
  font-weight: 500;
  color: var(--color-ink);
  letter-spacing: -0.005em;
  font-variation-settings: "opsz" 24, "SOFT" var(--display-soft, 30), "WONK" var(--display-wonk, 0);
}
.proposal-target-arrow {
  display: none; /* the layout flows naturally without an arrow glyph */
}
.proposal-target-vocab {
  font-size: 0.88rem;
  color: var(--color-accent);
  font-weight: 500;
}
.proposal-target-examples {
  font-size: 0.8rem;
  color: var(--color-ink-muted);
  font-style: italic;
}
.proposal-field {
  display: flex;
  flex-direction: column;
  gap: 0.3em;
  font-size: 0.88rem;
}
.proposal-field span {
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 600;
  color: var(--color-ink-muted);
}
.proposal-field textarea,
.proposal-field input {
  padding: 0.5em 0.7em;
  border: 1px solid var(--color-rule);
  border-radius: 3px;
  font: inherit;
  font-size: 0.92rem;
  background: var(--color-paper-soft);
  color: var(--color-ink);
}
.proposal-field textarea:focus,
.proposal-field input:focus {
  outline: none;
  border-color: var(--color-ink);
}
</style>
