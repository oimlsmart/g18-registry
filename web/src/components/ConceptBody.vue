<script setup lang="ts">
import { computed } from "vue";
import DefText from "./DefText.vue";

const props = defineProps<{
  data: {
    designations?: { type: string; status: string; text: string }[];
    definitions?: string[];
    notes?: string[];
    examples?: string[];
  } | null;
}>();

const preferred = computed(() =>
  props.data?.designations?.find(d => d.type === "expression" && d.status === "preferred")
);
const admitted = computed(() =>
  (props.data?.designations || []).filter(d => d.type === "expression" && d.status === "admitted")
);
const abbreviations = computed(() =>
  (props.data?.designations || []).filter(d => d.type === "abbreviation").map(d => d.text)
);
const symbols = computed(() =>
  (props.data?.designations || []).filter(d => d.type === "symbol").map(d => d.text)
);
</script>

<template>
  <div v-if="data" class="concept-body">
    <!-- Preferred designation: the term name, in display italic -->
    <div v-if="preferred" class="concept-term">
      <DefText :text="preferred.text" />
    </div>

    <!-- Admitted expressions -->
    <div v-if="admitted.length" class="concept-synonyms">
      <span class="concept-syn-label">Also</span>
      <span v-for="(a, i) in admitted" :key="i" class="concept-syn">
        <DefText :text="a.text" />
        <span v-if="i < admitted.length - 1" class="concept-syn-sep">·</span>
      </span>
    </div>

    <!-- Abbreviations -->
    <div v-if="abbreviations.length" class="concept-abbrevs">
      <span v-for="(abbr, i) in abbreviations" :key="i" class="concept-abbrev">{{ abbr }}</span>
    </div>

    <!-- Symbols -->
    <div v-if="symbols.length" class="concept-symbols">
      <span v-for="(sym, i) in symbols" :key="i" class="concept-symbol">{{ sym }}</span>
    </div>

    <!-- Definition -->
    <div v-if="data.definitions?.length" class="concept-defn">
      <p v-for="(def, i) in data.definitions" :key="i" class="concept-defn-body">
        <DefText :text="def" />
      </p>
    </div>

    <!-- Notes -->
    <div v-if="data.notes?.length" class="concept-section">
      <span class="concept-section-label">Notes</span>
      <ol class="concept-numbered-list">
        <li v-for="(note, i) in data.notes" :key="i">
          <DefText :text="note" />
        </li>
      </ol>
    </div>

    <!-- Examples -->
    <div v-if="data.examples?.length" class="concept-section">
      <span class="concept-section-label">Examples</span>
      <ol class="concept-numbered-list">
        <li v-for="(ex, i) in data.examples" :key="i">
          <DefText :text="ex" />
        </li>
      </ol>
    </div>
  </div>
</template>

<style>
/* ── Preferred term name ────────────────────────────────────────
   Dictionary-entry treatment: display serif, italic, prominent. */
.concept-term {
  font-family: var(--font-display);
  font-size: 1.25rem;
  font-weight: 500;
  font-style: italic;
  line-height: 1.3;
  color: var(--color-ink);
  margin-bottom: 0.15em;
  font-variation-settings: "opsz" 48, "SOFT" var(--display-soft, 30), "WONK" var(--display-wonk, 0);
  letter-spacing: -0.015em;
}

/* ── Admitted expressions ─────────────────────────────────────── */
.concept-synonyms {
  font-size: 0.88rem;
  color: var(--color-ink-soft);
  margin-bottom: 0.2em;
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0 0.3em;
}
.concept-syn-label {
  font-weight: 700;
  text-transform: uppercase;
  font-size: 0.66rem;
  letter-spacing: 0.1em;
  color: var(--color-ink-muted);
  margin-right: 0.2em;
}
.concept-syn-sep {
  color: var(--color-ink-muted);
}

/* ── Abbreviations ────────────────────────────────────────────── */
.concept-abbrevs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.3em;
  margin: 0.2em 0 0.4em;
}
.concept-abbrev {
  display: inline-block;
  font-family: var(--font-mono);
  font-size: 0.78rem;
  padding: 0.12em 0.5em;
  border-radius: 3px;
  background: var(--color-rule-soft);
  color: var(--color-ink-soft);
  letter-spacing: 0.02em;
}

/* ── Symbols ──────────────────────────────────────────────────── */
.concept-symbols {
  display: inline-flex;
  gap: 0.4em;
  margin-left: 0.3em;
}
.concept-symbol {
  font-family: var(--font-display);
  font-style: italic;
  font-size: 1.1rem;
  color: var(--color-ink);
}

/* ── Definition ───────────────────────────────────────────────── */
.concept-defn {
  margin: 0.7em 0 0.3em;
  padding-top: 0.6em;
  border-top: 1px solid var(--color-rule-soft);
}
.concept-defn-body {
  font-size: 0.96rem;
  line-height: 1.6;
  margin: 0.2em 0;
  color: var(--color-ink);
}

/* ── Notes / Examples ─────────────────────────────────────────── */
.concept-section {
  margin-top: 0.6em;
}
.concept-section-label {
  display: block;
  font-size: 0.66rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--color-ink-muted);
  margin-bottom: 0.25em;
}
.concept-numbered-list {
  margin: 0;
  padding-left: 1.4em;
}
.concept-numbered-list li {
  margin: 0.25em 0;
  line-height: 1.5;
  font-size: 0.88rem;
  color: var(--color-ink-soft);
}
</style>
