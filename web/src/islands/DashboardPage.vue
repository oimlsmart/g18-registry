<script setup lang="ts">
import dashboardData from "@/data/dashboard.json";
import conflictsData from "@/data/conflicts.json";
import SLink from "@/components/SLink.vue";

const dashboard = dashboardData as any;
const vocabGaps = dashboard;
const rawConflictCount = Object.values((conflictsData as any).raw || {}).flat().length;

const vimCount = dashboard.kind_counts["defined_in_vim"] || 0;
const vimlCount = dashboard.kind_counts["defined_in_viml"] || 0;
const oimlCount = (dashboard.kind_counts["oiml_original"] || 0) + (dashboard.kind_counts["undefined"] || 0);
const gapsVimlNearMiss = dashboard.gaps_viml_near_miss;
const gapsVimNearMiss = dashboard.gaps_vim_near_miss;
const gapsNoMatch = dashboard.gaps_no_match;
const terms = dashboard;

const priorityActions = dashboard.priority_terms || [];
const priorityLabel = (rank: number) =>
  rank === 0 ? "High" : rank === 1 ? "Medium" : rank === 2 ? "Info" : "Low";
const priorityBadge = (rank: number) =>
  rank === 0 ? "badge-ko" : rank === 1 ? "badge-partial" : "badge-pending";
</script>

<template>
  <div class="page-head reveal">
    <h1>OIML Concepts Management</h1>
    <p class="lede">
      Manage OIML terminology concepts, align them with authoritative vocabularies,
      and prepare future editions of V 1, V 2, V 3, and the generated G 18 Current.
    </p>
  </div>

  <!-- What is this platform -->
  <section class="card reveal reveal-1 platform-intro">
    <h2>What this platform does</h2>
    <p>
      OIML publications use hundreds of technical terms. This platform collates those terms,
      checks their alignment with the authoritative vocabularies (VIM/VIML), and helps TC 1
      prepare three outputs:
    </p>
    <div class="target-grid">
      <div class="target-card target-v1">
        <div class="target-label">V 1</div>
        <div class="target-title">Future VIML</div>
        <p>Concepts proposed for the next edition of the International Vocabulary of Legal Metrology.</p>
        <SLink to="/analysis/gaps/?scope=v1-match" class="target-link">{{ gapsVimlNearMiss }} candidates with VIML near-miss →</SLink>
      </div>
      <div class="target-card target-v2">
        <div class="target-label">V 2</div>
        <div class="target-title">Future VIM</div>
        <p>Concepts proposed for the next edition of the International Vocabulary of Metrology. Suggestions go to JCGM.</p>
        <SLink to="/analysis/gaps/?scope=v2-match" class="target-link">{{ gapsVimNearMiss }} candidates with VIM near-miss →</SLink>
      </div>
      <div class="target-card target-v3">
        <div class="target-label">V 3</div>
        <div class="target-title">OIML-specific terminology</div>
        <p>A new concept dataset for terms unique to OIML publications — not in VIM or VIML. Terms like "load cell", "dosimeter", "pressure gauge".</p>
        <SLink to="/analysis/gaps/?scope=v3-match" class="target-link">{{ gapsNoMatch }} candidates →</SLink>
      </div>
    </div>
  </section>

  <!-- G 18 editions status -->
  <section class="card reveal reveal-2 g18-status">
    <h2>G 18 editions</h2>
    <div class="g18-editions-grid">
      <div class="g18-edition-card">
        <div class="g18-edition-label">G 18:2010</div>
        <div class="g18-edition-status g18-status-published">Published</div>
        <p class="g18-edition-desc">The current published edition. Frozen — no changes possible.</p>
      </div>
      <div class="g18-edition-card">
        <div class="g18-edition-label">G 18:202X (2nd ed.)</div>
        <div class="g18-edition-status" :class="rawConflictCount > 0 ? 'g18-status-warn' : 'g18-status-ready'">
          {{ rawConflictCount > 0 ? `${rawConflictCount} ID conflicts` : 'Ready' }}
        </div>
        <p class="g18-edition-desc">
          Draft edition nearing publication.
          <span v-if="rawConflictCount > 0">
            <SLink :to="`/g18/conflicts/`">Resolve {{ rawConflictCount }} ID conflicts</SLink> to finalize.
          </span>
          <span v-else>No blocking issues.</span>
        </p>
      </div>
      <div class="g18-edition-card">
        <div class="g18-edition-label">G 18 Current (future)</div>
        <div class="g18-edition-status g18-status-future">Generated artifact</div>
        <p class="g18-edition-desc">
          Will be generated from the V 1/V 2/V 3 concept sets. Not yet available —
          concept alignment must reach sufficient coverage first.
        </p>
      </div>
    </div>
  </section>

  <!-- Corpus overview: concepts and publications with lifecycle -->
  <section class="card reveal reveal-2 corpus-overview">
    <div class="corpus-grid">
      <div class="corpus-block">
        <h2>Concepts</h2>
        <div class="corpus-stat-main">
          <span class="corpus-num">{{ dashboard.total_terms }}</span>
          <span class="corpus-unit">total concepts</span>
        </div>
        <div class="corpus-breakdown">
          <div class="corpus-row">
            <span class="corpus-dot corpus-dot-current"></span>
            <strong>{{ dashboard.concepts_from_current || 0 }}</strong> from current publications
          </div>
          <div class="corpus-row">
            <span class="corpus-dot corpus-dot-historic"></span>
            <strong>{{ dashboard.concepts_from_historic || 0 }}</strong> only from historic publications
          </div>
        </div>
      </div>
      <div class="corpus-block">
        <h2>Publications</h2>
        <div class="corpus-stat-main">
          <span class="corpus-num">{{ dashboard.total_publications }}</span>
          <span class="corpus-unit">total publications</span>
        </div>
        <div class="corpus-breakdown">
          <SLink to="/publications/" class="corpus-row">
            <span class="corpus-dot corpus-dot-current"></span>
            <strong>{{ dashboard.pub_current || 0 }}</strong> current
          </SLink>
          <SLink to="/publications/" class="corpus-row">
            <span class="corpus-dot corpus-dot-historic"></span>
            <strong>{{ dashboard.pub_retired || 0 }}</strong> retired
          </SLink>
          <SLink to="/publications/" class="corpus-row">
            <span class="corpus-dot corpus-dot-withdrawn"></span>
            <strong>{{ dashboard.pub_withdrawn || 0 }}</strong> withdrawn
          </SLink>
        </div>
      </div>
      <div class="corpus-block">
        <h2>Vocab alignment</h2>
        <div class="corpus-stat-main">
          <span class="corpus-num">{{ vimlCount + vimCount }}</span>
          <span class="corpus-unit">aligned with V 1/V 2</span>
        </div>
        <div class="corpus-breakdown">
          <div class="corpus-row">
            <span class="corpus-dot corpus-dot-v1"></span>
            <strong>{{ vimlCount }}</strong> from VIML (V 1)
          </div>
          <div class="corpus-row">
            <span class="corpus-dot corpus-dot-v2"></span>
            <strong>{{ vimCount }}</strong> from VIM (V 2)
          </div>
          <SLink to="/analysis/gaps/?scope=v3-match" class="corpus-row">
            <span class="corpus-dot corpus-dot-v3"></span>
            <strong>{{ oimlCount }}</strong> OIML-specific (V 3 candidates)
          </SLink>
        </div>
      </div>
    </div>
  </section>

  <!-- Priority worklist -->
  <section class="card reveal reveal-3" v-if="priorityActions.length">
    <div class="card-head">
      <h2>Priority worklist</h2>
      <SLink to="/analysis/actions/" class="external">View all →</SLink>
    </div>
    <div class="table-scroll">
      <table>
        <thead>
          <tr><th>Term</th><th>Action</th><th>Priority</th><th class="num">Pubs</th></tr>
        </thead>
        <tbody>
          <tr v-for="g in priorityActions" :key="g.slug">
            <td><SLink :to="`/concepts/${g.slug}/`">{{ g.name }}</SLink></td>
            <td>
              <span v-for="a in (g.actions || []).slice(0, 2)" :key="a" class="action-chip">{{ a.replace(/_/g, ' ') }}</span>
            </td>
            <td><span :class="['badge', priorityBadge(g.priority_rank)]">{{ priorityLabel(g.priority_rank) }}</span></td>
            <td class="num">{{ g.pub_count }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <!-- Audience links -->
  <section class="audience-grid reveal reveal-4">
    <article class="audience-card">
      <h2 class="audience-name">TC 1 / Vocabularies</h2>
      <ul class="audience-links">
        <li><SLink to="/analysis/actions/">Suggested actions</SLink></li>
        <li><SLink to="/analysis/gaps/">Vocabulary gaps</SLink></li>
        <li><SLink to="/analysis/divergence/">Top divergence</SLink></li>
        <li><SLink to="/g18/conflicts/">ID conflicts</SLink></li>
      </ul>
    </article>
    <article class="audience-card">
      <h2 class="audience-name">TC/SC secretaries</h2>
      <ul class="audience-links">
        <li><SLink to="/tc/">Your TC/SC</SLink></li>
        <li><SLink to="/publications/">Your publications</SLink></li>
      </ul>
    </article>
    <article class="audience-card">
      <h2 class="audience-name">Publication authors</h2>
      <ul class="audience-links">
        <li><SLink to="/concepts/">Browse concepts</SLink></li>
        <li><SLink to="/how-to-use/">How to use</SLink></li>
      </ul>
    </article>
  </section>
</template>

<style scoped>
.platform-intro { margin-bottom: 1.2em; }
.platform-intro p { color: var(--color-ink-soft); line-height: 1.6; }
.target-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1em;
  margin-top: 1em;
}
@media (max-width: 720px) { .target-grid { grid-template-columns: 1fr; } }
.target-card {
  padding: 0.9em 1.1em;
  border-radius: 6px;
  border-left: 4px solid;
}
.target-v1 { background: var(--status-ok-bg); border-color: var(--status-ok-border); }
.target-v2 { background: var(--status-info-bg); border-color: var(--status-info-border); }
.target-v3 { background: var(--status-warn-bg); border-color: var(--status-warn-border); }
.target-label {
  font-family: var(--font-mono);
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  opacity: 0.7;
}
.target-title {
  font-family: var(--font-display);
  font-size: 1.05rem;
  font-weight: 500;
  margin: 0.15em 0 0.3em;
  color: var(--color-ink);
}
.target-card p { font-size: 0.84rem; margin: 0 0 0.4em; color: var(--color-ink-soft); }
.target-link { font-size: 0.82rem; font-weight: 600; }

.g18-status { margin-bottom: 1.2em; }
.g18-editions-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1em;
  margin-top: 0.8em;
}
@media (max-width: 720px) { .g18-editions-grid { grid-template-columns: 1fr; } }
.g18-edition-card {
  padding: 0.8em 1em;
  border-radius: 4px;
  border: 1px solid var(--color-rule-soft);
  background: var(--color-paper);
}
.g18-edition-label {
  font-family: var(--font-display);
  font-weight: 500;
  font-size: 0.95rem;
  color: var(--color-ink);
}
.g18-edition-status {
  display: inline-block;
  font-size: 0.72rem;
  font-weight: 600;
  padding: 0.15em 0.5em;
  border-radius: 3px;
  margin: 0.3em 0;
}
.g18-status-published { background: var(--color-rule-soft); color: var(--color-ink-muted); }
.g18-status-ready { background: var(--status-ok-bg); color: var(--status-ok-text); }
.g18-status-warn { background: var(--status-warn-bg); color: var(--status-warn-text); }
.g18-status-future { background: var(--status-info-bg); color: var(--status-info-text); }
.g18-edition-desc { font-size: 0.82rem; color: var(--color-ink-soft); margin: 0.3em 0 0; line-height: 1.4; }

.action-chip {
  display: inline-block;
  font-size: 0.7rem;
  padding: 0.1em 0.4em;
  border-radius: 2px;
  background: var(--color-rule-soft);
  color: var(--color-ink-soft);
  margin-right: 0.3em;
}
.corpus-overview { margin-bottom: 1.2em; }
.corpus-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5em;
  margin-top: 0.8em;
}
@media (max-width: 720px) { .corpus-grid { grid-template-columns: 1fr; } }
.corpus-block h2 {
  font-size: 0.82rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-ink-muted);
  margin: 0 0 0.5em;
}
.corpus-stat-main {
  display: flex;
  align-items: baseline;
  gap: 0.3em;
  margin-bottom: 0.6em;
}
.corpus-num {
  font-family: var(--font-display);
  font-size: 2rem;
  font-weight: 400;
  letter-spacing: -0.03em;
  color: var(--color-ink);
  font-variation-settings: "opsz" 96, "SOFT" var(--display-soft, 30), "WONK" var(--display-wonk, 0);
}
.corpus-unit { font-size: 0.85rem; color: var(--color-ink-soft); }
.corpus-breakdown { display: flex; flex-direction: column; gap: 0.35em; }
.corpus-row {
  display: flex;
  align-items: center;
  gap: 0.4em;
  font-size: 0.86rem;
  color: var(--color-ink-soft);
  text-decoration: none;
  transition: color 0.15s;
}
.corpus-row:hover { color: var(--color-accent); }
.corpus-row strong { color: var(--color-ink); font-weight: 600; font-variant-numeric: tabular-nums; }
.corpus-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.corpus-dot-current { background: var(--status-ok-border, #16a34a); }
.corpus-dot-historic { background: var(--color-ink-muted); opacity: 0.5; }
.corpus-dot-withdrawn { background: var(--status-error-border, #dc2626); }
.corpus-dot-v1 { background: var(--status-ok-border, #16a34a); }
.corpus-dot-v2 { background: var(--status-info-border, #3b82f6); }
.corpus-dot-v3 { background: var(--color-accent); }
</style>
