<script setup lang="ts">
import SLink from "@/components/SLink.vue";
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>How to use</span></div>
    <h1>How concepts management works</h1>
    <p class="lede">
      This platform helps TC 1 / Vocabularies align every term used across OIML
      publications with the authoritative vocabularies (VIM, VIML) and decide
      where OIML-specific terms belong in the future vocabulary landscape.
    </p>
  </div>

  <!-- What this platform does -->
  <section class="card">
    <h2>What this platform does</h2>
    <p>
      OIML publications (Recommendations, Documents) use thousands of technical
      terms. Many of these terms are defined in the authoritative vocabularies:
    </p>
    <ul class="htu-list">
      <li><strong>V 1 (VIML)</strong> — International Vocabulary of Terms in Legal Metrology</li>
      <li><strong>V 2 (VIM)</strong> — International Vocabulary of Metrology (maintained by JCGM)</li>
    </ul>
    <p>
      Terms not in V 1 or V 2 are OIML-specific. These need a home in a future
      <strong>V 3</strong> — a proposed new vocabulary for OIML-specific terms.
    </p>
    <p>
      For each concept, the platform collates every OIML publication that uses it,
      checks its alignment with V 1/V 2, and recommends an action. <strong>G 18</strong>
      is the OIML guide that assembles these terms into a shared terminology resource.
      G 18 itself is not a vocabulary — it sources concepts from V 1, V 2, and OIML publications.
    </p>
  </section>

  <!-- The decision tree -->
  <section class="card">
    <h2>The 5-case alignment decision tree</h2>
    <p>
      For each concept, the platform compares its designation <em>and</em>
      definition against the current authoritative V 1 (VIML 2022) and
      V 2 (VIM 2012) vocabularies. The result is one of five alignment
      cases, each with a recommended action.
    </p>

    <!-- Case 1: Aligned -->
    <div class="case-card case-aligned">
      <div class="case-header">
        <span class="case-badge badge-aligned">Case 1</span>
        <h3>Aligned</h3>
        <span class="case-tag">designation + definition match</span>
      </div>
      <p class="case-intro">
        Designation and normalized definition are identical to the current
        V 1 or V 2 concept. The OIML publication is consistent with the
        authoritative vocabulary.
      </p>
      <div class="case-outcome case-outcome-ok">
        Action: <strong>None.</strong> Concept is already aligned — show as info on the worklist.
      </div>
    </div>

    <!-- Case 2: Historic match -->
    <div class="case-card case-historic">
      <div class="case-header">
        <span class="case-badge badge-historic">Case 2</span>
        <h3>Matches a historic edition only</h3>
        <span class="case-tag">citation needs update</span>
      </div>
      <p class="case-intro">
        The concept matches an older V 1/V 2 edition (e.g. VIM 2007, VIML
        2013) but the citation is stale — the current edition has either
        renumbered or refined the definition.
      </p>
      <div class="case-outcome case-outcome-warn">
        Action: <strong>Update the citation.</strong> The publication should
        cite the latest V 1/V 2 edition in its next revision.
      </div>
    </div>

    <!-- Case 3: Definition diverges -->
    <div class="case-card case-diverges">
      <div class="case-header">
        <span class="case-badge badge-diverges">Case 3</span>
        <h3>Definition diverges</h3>
        <span class="case-tag">same designation, different definition</span>
      </div>
      <p class="case-intro">
        The designation matches the current V 1/V 2, but the definition
        differs meaningfully. Either the OIML publication intentionally
        diverges, or it has drifted.
      </p>
      <div class="case-outcome case-outcome-action">
        Options: <strong>Adopt the V 1/V 2 definition</strong> (update the
        publication), or <strong>differentiate the designation</strong>
        (rename the OIML term) and propose the new concept for V 3.
      </div>
    </div>

    <!-- Case 4: Fuzzy match -->
    <div class="case-card case-fuzzy">
      <div class="case-header">
        <span class="case-badge badge-fuzzy">Case 4</span>
        <h3>Fuzzy designation match</h3>
        <span class="case-tag">similar term exists in V 1/V 2</span>
      </div>
      <p class="case-intro">
        No exact designation match, but the term closely resembles a V 1/V 2
        concept (detected via token-overlap similarity). TC 1 must judge
        whether the OIML term is a synonym, a specialization, or distinct.
      </p>
      <div class="case-outcome case-outcome-action">
        Options: <strong>Adopt the V 1/V 2 term</strong> (reconcile the
        near-miss), or <strong>Propose for V 3</strong> as sufficiently
        distinct.
      </div>
    </div>

    <!-- Case 5: No match -->
    <div class="case-card case-none">
      <div class="case-header">
        <span class="case-badge badge-none">Case 5</span>
        <h3>No match</h3>
        <span class="case-tag">OIML-specific</span>
      </div>
      <p class="case-intro">
        No V 1 or V 2 concept matches the designation, even with fuzzy
        matching. The term is genuinely OIML-specific — examples include
        "load cell", "dosimeter", "pressure gauge".
      </p>
      <div class="case-outcome case-outcome-ok">
        Action: <strong>Propose for V 3.</strong> The future OIML-specific
        vocabulary is the right home for these terms.
      </div>
    </div>

    <!-- Auxiliary: Withdrawn publication -->
    <div class="case-card case-withdrawn">
      <div class="case-header">
        <span class="case-badge badge-withdrawn">Auxiliary</span>
        <h3>Withdrawn publication</h3>
        <span class="case-tag">retire from G 18</span>
      </div>
      <p class="case-intro">
        Independent of the 5 alignment cases: when an OIML publication is
        withdrawn (status from relaton-data-oiml), concepts that appear
        only in that publication should be retired from G 18:current and
        G 18:202X. The platform auto-detects this and flags a "Retire"
        action.
      </p>
      <div class="case-outcome case-outcome-action">
        Action: <strong>Retire from G 18:current and G 18:202X.</strong>
        The concept is no longer sourced from an active publication.
      </div>
    </div>
  </section>

  <!-- Target vocabularies -->
  <section class="card">
    <h2>The three target vocabularies</h2>
    <div class="target-vocab-grid">
      <div class="target-vocab-card tv-v1">
        <div class="tv-label">V 1</div>
        <div class="tv-name">Future VIML</div>
        <p>Legal metrology concepts: verification, type approval, legal control of measuring instruments.</p>
        <SLink to="/analysis/gaps/?scope=v1-match" class="tv-link">V 1 candidates →</SLink>
      </div>
      <div class="target-vocab-card tv-v2">
        <div class="tv-label">V 2</div>
        <div class="tv-name">Future VIM</div>
        <p>General metrology concepts: quantity, measurement, accuracy, uncertainty. Suggestions go to JCGM.</p>
        <SLink to="/analysis/gaps/?scope=v2-match" class="tv-link">V 2 candidates →</SLink>
      </div>
      <div class="target-vocab-card tv-v3">
        <div class="tv-label">V 3</div>
        <div class="tv-name">OIML-specific</div>
        <p>A new vocabulary for terms unique to OIML publications — not in VIM or VIML. Load cell, dosimeter, pressure gauge.</p>
        <SLink to="/analysis/gaps/?scope=v3-match" class="tv-link">V 3 candidates →</SLink>
      </div>
    </div>
  </section>

  <!-- Where to start -->
  <section class="card">
    <h2>Where to start</h2>
    <div class="start-grid">
      <SLink to="/analysis/actions/" class="start-card">
        <strong>Suggested actions</strong>
        <p>Every concept that needs attention, ranked by priority.</p>
      </SLink>
      <SLink to="/analysis/gaps/" class="start-card">
        <strong>Vocabulary gaps</strong>
        <p>OIML terms with no V 1/V 2 source. Triage by V 1, V 2, or V 3 candidacy.</p>
      </SLink>
      <SLink to="/concepts/" class="start-card">
        <strong>Browse concepts</strong>
        <p>All concepts defined in OIML publications, filterable by edition.</p>
      </SLink>
    </div>
  </section>

  <!-- Key concepts glossary -->
  <section class="card">
    <h2>Key concepts</h2>
    <dl class="glossary">
      <dt>V 1 (VIML)</dt>
      <dd>International Vocabulary of Terms in Legal Metrology — legal metrology terms (verification, type approval, legal control).</dd>
      <dt>V 2 (VIM)</dt>
      <dd>International Vocabulary of Metrology — general metrology terms (quantity, measurement, accuracy). Maintained by JCGM; OIML proposes suggestions.</dd>
      <dt>V 3</dt>
      <dd>A proposed new vocabulary for OIML-specific terms not in V 1 or V 2 (e.g. "load cell", "dosimeter", "pressure gauge").</dd>
      <dt>Alignment case</dt>
      <dd>One of 5 classifications (1=aligned, 2=historic, 3=diverges, 4=fuzzy, 5=none) computed by comparing a term's designation and normalized definition against the current V 1/V 2 editions. Drives the recommended action.</dd>
      <dt>G 18</dt>
      <dd>The OIML guide that collates terminology used across OIML Recommendations and Documents. G 18 sources concepts from V 1, V 2, and OIML publications — it is not itself a vocabulary. G 18:2010 is published; G 18:202X is the draft under review.</dd>
      <dt>Fuzzy match</dt>
      <dd>An OIML term whose designation closely resembles (but does not exactly match) a V 1/V 2 concept — detected by Jaccard token-overlap similarity (threshold 0.34). Drives Case 4 alignment.</dd>
      <dt>Differentiated definitions</dt>
      <dd>When the same term appears with different definitions across OIML publications, the platform shows all variants as reference material to help decide harmonization.</dd>
      <dt>Concept diff</dt>
      <dd>A structured comparison between two V 1/V 2 editions showing what changed: designation renames, definition rewording, added/removed notes and examples.</dd>
    </dl>
  </section>
</template>

<style scoped>
.htu-list {
  margin: 0.5em 0 1em;
  padding-left: 1.2em;
}
.htu-list li {
  margin-bottom: 0.3em;
  font-size: 0.9rem;
  color: var(--color-ink-soft);
}

.case-card {
  border: 1px solid var(--color-rule);
  border-radius: var(--radius-card);
  padding: 1em 1.2em;
  margin-top: 1em;
  background: var(--color-paper);
}
.case-aligned    { border-left: 4px solid var(--status-ok-border); }
.case-historic   { border-left: 4px solid var(--status-info-border); }
.case-diverges   { border-left: 4px solid var(--status-warn-border); }
.case-fuzzy      { border-left: 4px solid var(--color-accent); }
.case-none       { border-left: 4px solid var(--color-rule); }
.case-withdrawn  { border-left: 4px solid var(--status-error-border); }

.case-header {
  display: flex;
  align-items: center;
  gap: 0.6em;
  margin-bottom: 0.4em;
  flex-wrap: wrap;
}
.case-badge {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 0.15em 0.5em;
  border-radius: 3px;
}
.badge-aligned   { background: var(--status-ok-bg);    color: var(--status-ok-text); }
.badge-historic  { background: var(--status-info-bg);  color: var(--status-info-text); }
.badge-diverges  { background: var(--status-warn-bg);  color: var(--status-warn-text); }
.badge-fuzzy     { background: var(--color-accent-tint, var(--status-info-bg)); color: var(--color-accent); }
.badge-none      { background: var(--color-rule-soft); color: var(--color-ink-muted); }
.badge-withdrawn { background: var(--status-error-bg); color: var(--status-error-text); }

.case-tag {
  font-size: 0.74rem;
  color: var(--color-ink-muted);
  font-style: italic;
  margin-left: auto;
}
.case-header h3 {
  margin: 0;
  font-size: 1.05rem;
  font-family: var(--font-display);
  font-weight: 500;
  color: var(--color-ink);
}
.case-intro {
  font-size: 0.88rem;
  color: var(--color-ink-soft);
  margin: 0.3em 0 0.8em;
  line-height: 1.5;
}

.case-outcome {
  font-size: 0.84rem;
  padding: 0.5em 0.7em;
  border-radius: 4px;
  margin-top: 0.3em;
  line-height: 1.4;
}
.case-outcome-ok {
  background: var(--status-ok-bg);
  color: var(--status-ok-text);
  border-left: 3px solid var(--status-ok-border);
}
.case-outcome-warn {
  background: var(--status-warn-bg);
  color: var(--status-warn-text);
  border-left: 3px solid var(--status-warn-border);
}
.case-outcome-action {
  background: var(--status-info-bg);
  color: var(--status-info-text);
  border-left: 3px solid var(--status-info-border);
}

.options-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.7em;
  margin: 0.8em 0;
}
@media (max-width: 720px) {
  .options-grid { grid-template-columns: 1fr; }
}
.option-card {
  display: flex;
  gap: 0.6em;
  padding: 0.7em 0.8em;
  border: 1px solid var(--color-rule);
  border-radius: 4px;
  background: var(--color-paper-tint);
}
.option-letter {
  flex-shrink: 0;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--color-accent);
  color: #fff;
  font-size: 0.75rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.option-body p {
  margin: 0.2em 0 0;
  font-size: 0.82rem;
  color: var(--color-ink-soft);
  line-height: 1.4;
}

.target-vocab-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.8em;
  margin-top: 0.8em;
}
@media (max-width: 720px) {
  .target-vocab-grid { grid-template-columns: 1fr; }
}
.target-vocab-card {
  padding: 0.8em 1em;
  border-radius: 4px;
  border-left: 4px solid;
}
.tv-v1 { background: var(--status-ok-bg); border-color: var(--status-ok-border); }
.tv-v2 { background: var(--status-info-bg); border-color: var(--status-info-border); }
.tv-v3 { background: var(--status-warn-bg); border-color: var(--status-warn-border); }
.tv-label {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  opacity: 0.7;
}
.tv-name {
  font-family: var(--font-display);
  font-size: 1rem;
  font-weight: 500;
  margin: 0.1em 0 0.3em;
  color: var(--color-ink);
}
.target-vocab-card p {
  font-size: 0.83rem;
  margin: 0 0 0.4em;
  color: var(--color-ink-soft);
  line-height: 1.4;
}
.tv-link {
  font-size: 0.8rem;
  font-weight: 600;
}

.start-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.7em;
  margin-top: 0.8em;
}
@media (max-width: 720px) {
  .start-grid { grid-template-columns: 1fr; }
}
.start-card {
  display: block;
  padding: 0.8em 1em;
  border: 1px solid var(--color-rule);
  border-radius: 4px;
  background: var(--color-paper);
  text-decoration: none;
  transition: border-color 0.15s, background 0.15s;
}
.start-card:hover {
  border-color: var(--color-accent);
  background: var(--color-accent-tint);
}
.start-card strong {
  display: block;
  font-size: 0.92rem;
  color: var(--color-ink);
  font-family: var(--font-display);
  font-weight: 500;
}
.start-card p {
  margin: 0.2em 0 0;
  font-size: 0.82rem;
  color: var(--color-ink-soft);
  line-height: 1.4;
}

.glossary {
  margin: 0;
}
.glossary dt {
  font-weight: 600;
  font-size: 0.88rem;
  color: var(--color-ink);
  margin-top: 0.5em;
}
.glossary dd {
  margin-left: 1.2em;
  font-size: 0.85rem;
  color: var(--color-ink-soft);
  line-height: 1.45;
}
</style>
