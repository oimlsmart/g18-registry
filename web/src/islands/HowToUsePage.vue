<script setup lang="ts">
import SLink from "@/components/SLink.vue";
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>How to use</span></div>
    <h1>How terminology harmonization works</h1>
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
    <h2>The harmonization decision tree</h2>
    <p>
      For each concept, the platform follows a decision tree. The recommended
      action depends on whether the concept is sourced from V 1/V 2 or is OIML-original.
    </p>

    <!-- Case 1: Sourced from V1/V2 -->
    <div class="case-card case-sourced">
      <div class="case-header">
        <span class="case-badge">Case 1</span>
        <h3>Concept is sourced from V 1/V 2</h3>
      </div>
      <p class="case-intro">
        The OIML publication adopted this term from VIM or VIML. The question is
        whether the citation is current.
      </p>
      <ol class="case-steps">
        <li>
          <strong>Is the citation up to date?</strong>
          <p>The publication cites the current edition of V 1/V 2 for this concept.</p>
          <div class="case-outcome case-outcome-ok">
            Yes — <strong>nothing to do.</strong> The publication is aligned with the authoritative vocabulary.
          </div>
        </li>
        <li>
          <strong>If not current — update the citation.</strong>
          <p>
            A newer edition of V 1/V 2 exists. The recommendation is to update
            the publication to cite the latest edition in its next revision.
          </p>
          <div class="case-outcome case-outcome-warn">
            Action: <strong>Update the recommendation</strong> to cite the latest V 1/V 2 edition.
          </div>
        </li>
        <li>
          <strong>If the term was deleted from V 1/V 2</strong>
          <p>
            The concept no longer exists in the authoritative vocabulary.
            Decide where it should live now:
          </p>
          <div class="case-outcome case-outcome-action">
            Options: <strong>Propose for re-inclusion in V 1</strong> (legal metrology),
            <strong>V 2</strong> (general metrology), or <strong>V 3</strong> (OIML-specific).
          </div>
        </li>
      </ol>
    </div>

    <!-- Case 2: OIML-original -->
    <div class="case-card case-original">
      <div class="case-header">
        <span class="case-badge case-badge-original">Case 2</span>
        <h3>Concept is OIML-original (not sourced from V 1/V 2)</h3>
      </div>
      <p class="case-intro">
        The term was defined within OIML publications, not adopted from VIM/VIML.
        The platform checks whether it resembles an existing V 1/V 2 concept.
      </p>
      <ol class="case-steps">
        <li>
          <strong>Does it resemble a VIM/VIML concept?</strong>
          <p>
            The platform runs a near-miss match against V 1/V 2. If a similar
            designation or overlapping definition exists, these options apply:
          </p>
        </li>
      </ol>
      <div class="options-grid">
        <div class="option-card">
          <div class="option-letter">A</div>
          <div class="option-body">
            <strong>Adopt the V 1/V 2 term</strong>
            <p>Re-link the publication to the existing authoritative concept instead of the OIML-original definition.</p>
          </div>
        </div>
        <div class="option-card">
          <div class="option-letter">B</div>
          <div class="option-body">
            <strong>Propose for V 3</strong>
            <p>Use the V 1/V 2 term as a basis for a new OIML-specific entry in the future V 3 vocabulary.</p>
          </div>
        </div>
        <div class="option-card">
          <div class="option-letter">C</div>
          <div class="option-body">
            <strong>Update the recommendation</strong>
            <p>Replace the term in the publication with a different, better-aligned concept.</p>
          </div>
        </div>
      </div>
      <ol class="case-steps" start="2">
        <li>
          <strong>No near-miss — propose for V 3.</strong>
          <p>
            If no similar V 1/V 2 concept exists, the term is genuinely OIML-specific
            (e.g. "load cell", "dosimeter", "pressure gauge"). Propose it for inclusion
            in V 3.
          </p>
        </li>
      </ol>
    </div>

    <!-- Reference material -->
    <div class="case-card case-reference">
      <div class="case-header">
        <span class="case-badge case-badge-ref">Reference</span>
        <h3>Differentiated definitions</h3>
      </div>
      <p class="case-intro">
        When multiple OIML publications use the same term with different definitions,
        the platform surfaces these <strong>differentiated definitions</strong> as
        reference material. They help you understand how the term is actually used
        across the OIML corpus and inform the decisions above.
      </p>
      <p>
        For example, if "calibration" appears with slightly different wording in
        R 60, R 76, and R 117, all three definitions are shown side-by-side so you
        can see the divergence and decide whether to unify them.
      </p>
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
        <SLink to="/analysis/gaps/?scope=viml-match" class="tv-link">V 1 candidates →</SLink>
      </div>
      <div class="target-vocab-card tv-v2">
        <div class="tv-label">V 2</div>
        <div class="tv-name">Future VIM</div>
        <p>General metrology concepts: quantity, measurement, accuracy, uncertainty. Suggestions go to JCGM.</p>
        <SLink to="/analysis/gaps/?scope=vim-match" class="tv-link">V 2 candidates →</SLink>
      </div>
      <div class="target-vocab-card tv-v3">
        <div class="tv-label">V 3</div>
        <div class="tv-name">OIML-specific</div>
        <p>A new vocabulary for terms unique to OIML publications — not in VIM or VIML. Load cell, dosimeter, pressure gauge.</p>
        <SLink to="/analysis/gaps/?scope=no-match" class="tv-link">V 3 candidates →</SLink>
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
      <dt>G 18</dt>
      <dd>The OIML guide that collates terminology used across OIML Recommendations and Documents. G 18 sources concepts from V 1, V 2, and OIML publications — it is not itself a vocabulary. G 18:2010 is published; G 18:202X is the draft under review.</dd>
      <dt>Near-miss</dt>
      <dd>An OIML term that closely resembles (but does not exactly match) a V 1/V 2 concept — detected by token overlap and fuzzy matching. Indicates the term may be adoptable from or based on the authoritative vocabulary.</dd>
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
.case-sourced { border-left: 4px solid var(--status-ok-border); }
.case-original { border-left: 4px solid var(--status-warn-border); }
.case-reference { border-left: 4px solid var(--status-info-border); }

.case-header {
  display: flex;
  align-items: center;
  gap: 0.6em;
  margin-bottom: 0.4em;
}
.case-badge {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 0.15em 0.5em;
  border-radius: 3px;
  background: var(--status-ok-bg);
  color: var(--status-ok-text);
}
.case-badge-original {
  background: var(--status-warn-bg);
  color: var(--status-warn-text);
}
.case-badge-ref {
  background: var(--status-info-bg);
  color: var(--status-info-text);
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

.case-steps {
  margin: 0;
  padding-left: 1.2em;
  display: flex;
  flex-direction: column;
  gap: 0.8em;
}
.case-steps li {
  font-size: 0.88rem;
  color: var(--color-ink);
  line-height: 1.5;
}
.case-steps li > strong {
  display: block;
  margin-bottom: 0.2em;
}
.case-steps li p {
  margin: 0 0 0.4em;
  font-size: 0.85rem;
  color: var(--color-ink-soft);
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
