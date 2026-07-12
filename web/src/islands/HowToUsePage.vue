<script setup lang="ts">
import SLink from "@/components/SLink.vue";

const audiences = [
  {
    id: "tc1",
    title: "TC 1 — Vocabularies committee",
    summary: "Audit G 18 terms against VIM/VIML, decide which need action, and propose changes.",
    steps: [
      { icon: "📋", label: "Review the Actions worklist", desc: "Terms sorted by priority — start with HIGH.", page: "/analysis/actions/" },
      { icon: "🔍", label: "Open a term", desc: "Check the action box: what TC 1 should do.", page: "/concepts/adjustment/" },
      { icon: "📊", label: "Review the evidence", desc: "Concept diff shows what changed between VIM editions.", page: null },
      { icon: "✅", label: "Take action", desc: "Upgrade citation, harmonize definitions, or propose for V 1/V 2/V 3.", page: "/analysis/gaps/" },
    ],
  },
  {
    id: "editor",
    title: "Publication editors (TC/SC)",
    summary: "Check whether your OIML publications cite current VIM/VIML definitions.",
    steps: [
      { icon: "📚", label: "Open your publication", desc: "Find it in the Publications list.", page: "/publications/" },
      { icon: "⚠️", label: "Check terms needing action", desc: "The detail page flags outdated citations.", page: null },
      { icon: "📊", label: "Review the concept diff", desc: "See what changed in the VIM definition since your edition.", page: null },
      { icon: "📝", label: "Update in next edition", desc: "Re-cite the current VIM edition, or document divergence.", page: null },
    ],
  },
  {
    id: "general",
    title: "General users",
    summary: "Look up OIML terms and understand their relationship to VIM/VIML.",
    steps: [
      { icon: "🔎", label: "Search for a term", desc: "Use the Terms list with search and filters.", page: "/concepts/" },
      { icon: "📖", label: "Read the concept", desc: "The concept card shows the authoritative VIM/VIML definition.", page: null },
      { icon: "🏷️", label: "Check the status", desc: "Current, superseded, or removed from VIM/VIML.", page: null },
    ],
  },
];
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>How to use</span></div>
    <h1>How to use the G 18 registry</h1>
    <p class="lede">G 18 is a working tool for harmonising OIML terminology with VIM and VIML. Pick your role below to see the workflow.</p>
  </div>

  <!-- Audience navigation -->
  <div class="audience-nav">
    <a v-for="a in audiences" :key="a.id" :href="`#${a.id}`" class="audience-nav-item">
      {{ a.title }}
    </a>
  </div>

  <!-- Audience sections -->
  <section v-for="a in audiences" :key="a.id" :id="a.id" class="card audience-section">
    <h2>{{ a.title }}</h2>
    <p class="audience-summary">{{ a.summary }}</p>

    <!-- SVG flow diagram -->
    <div class="flow-diagram">
      <svg :viewBox="`0 0 ${a.steps.length * 200 + 40} 140`" class="flow-svg" xmlns="http://www.w3.org/2000/svg">
        <!-- Connector line -->
        <line
          x1="60" y1="50" :x2="a.steps.length * 200 - 20" y2="50"
          stroke="var(--color-rule)" stroke-width="2" stroke-dasharray="4 4"
        />
        <!-- Steps -->
        <g v-for="(step, i) in a.steps" :key="i" :transform="`translate(${i * 200 + 40}, 0)`">
          <!-- Circle -->
          <circle cx="20" cy="50" r="28" :fill="i === 0 ? 'var(--color-accent)' : i === a.steps.length - 1 ? 'var(--color-green)' : 'var(--color-paper-tint)'" stroke="var(--color-rule)" stroke-width="1.5" />
          <!-- Number -->
          <text x="20" y="56" text-anchor="middle" :fill="i === 0 || i === a.steps.length - 1 ? '#fff' : 'var(--color-ink)'" font-size="16" font-weight="700">{{ i + 1 }}</text>
          <!-- Arrow (except last) -->
          <polygon v-if="i < a.steps.length - 1" :points="`${i * 200 + 200 - 10},45 ${i * 200 + 200},50 ${i * 200 + 200 - 10},55`" fill="var(--color-ink-muted)" />
          <!-- Label -->
          <text x="20" y="100" text-anchor="middle" font-size="11" font-weight="600" fill="var(--color-ink)">{{ step.label.length > 22 ? step.label.substring(0, 20) + '…' : step.label }}</text>
          <text x="20" y="118" text-anchor="middle" font-size="9" fill="var(--color-ink-muted)">{{ step.icon }} {{ step.page ? '→' : '' }}</text>
        </g>
      </svg>
    </div>

    <!-- Step cards -->
    <div class="audience-steps">
      <div v-for="(step, i) in a.steps" :key="i" class="audience-step">
        <div class="audience-step-num">{{ i + 1 }}</div>
        <div class="audience-step-body">
          <div class="audience-step-label">{{ step.icon }} {{ step.label }}</div>
          <div class="audience-step-desc">{{ step.desc }}</div>
          <SLink v-if="step.page" :to="step.page" class="audience-step-link">Go →</SLink>
        </div>
      </div>
    </div>
  </section>

  <!-- Key concepts -->
  <section class="card">
    <h2>Key concepts</h2>
    <dl class="glossary">
      <dt>VIM (V 2)</dt>
      <dd>International Vocabulary of Metrology — general metrology terms (quantity, measurement, accuracy).</dd>
      <dt>VIML (V 1)</dt>
      <dd>International Vocabulary of Legal Metrology — legal metrology terms (verification, type approval, legal control).</dd>
      <dt>V 3</dt>
      <dd>A proposed new vocabulary for OIML-specific terms not in VIM or VIML (e.g. "load cell", "dosimeter").</dd>
      <dt>G 18</dt>
      <dd>The OIML guide that collates terminology used across OIML Recommendations and Documents. G 18:2010 is published; G 18:202X is the draft under review.</dd>
      <dt>Concept diff</dt>
      <dd>A structured comparison between two VIM/VIML editions showing what changed: designation renames, definition rewording, added/removed notes and examples.</dd>
    </dl>
  </section>
</template>

<style scoped>
.audience-nav {
  display: flex;
  gap: 0.5em;
  flex-wrap: wrap;
  margin-bottom: 1.2em;
}
.audience-nav-item {
  padding: 0.4em 0.9em;
  border-radius: 4px;
  background: var(--color-paper-tint);
  border: 1px solid var(--color-rule-soft);
  text-decoration: none;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--color-ink-soft);
}
.audience-nav-item:hover {
  background: var(--color-accent-tint);
  border-color: var(--color-accent);
  color: var(--color-accent);
}
.audience-section {
  margin-bottom: 1.2em;
}
.audience-summary {
  color: var(--color-ink-soft);
  font-size: 0.9rem;
  margin: 0.3em 0 0.8em;
}
.flow-diagram {
  overflow-x: auto;
  margin: 0.5em 0 1em;
  padding: 0.5em 0;
}
.flow-svg {
  min-width: 600px;
  height: auto;
}
.audience-steps {
  display: flex;
  flex-direction: column;
  gap: 0.6em;
}
.audience-step {
  display: flex;
  gap: 0.7em;
  align-items: flex-start;
}
.audience-step-num {
  flex-shrink: 0;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: var(--color-accent);
  color: #fff;
  font-size: 0.78rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 0.1em;
}
.audience-step-body {
  flex: 1;
}
.audience-step-label {
  font-weight: 600;
  font-size: 0.9rem;
  color: var(--color-ink);
}
.audience-step-desc {
  font-size: 0.82rem;
  color: var(--color-ink-soft);
  line-height: 1.4;
}
.audience-step-link {
  display: inline-block;
  margin-top: 0.2em;
  font-size: 0.8rem;
  font-weight: 600;
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
