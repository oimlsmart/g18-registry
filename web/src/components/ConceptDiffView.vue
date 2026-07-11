<script setup lang="ts">
defineProps<{
  diff: any;
}>();
</script>

<template>
  <div v-if="diff" class="concept-diff">
    <!-- Designation changes -->
    <div v-if="diff.designations" class="concept-diff-section">
      <span class="concept-diff-label">Designation changes</span>
      <div v-if="diff.designations.removed?.length" class="concept-diff-removed">
        <span v-for="d in diff.designations.removed" :key="d" class="diff-strike">{{ d }}</span>
      </div>
      <div v-if="diff.designations.added?.length" class="concept-diff-added">
        <span v-for="d in diff.designations.added" :key="d" class="diff-new">{{ d }}</span>
      </div>
      <div v-if="diff.designations.changed?.length" class="concept-diff-changed">
        <div v-for="(c, i) in diff.designations.changed" :key="i" class="diff-change-row">
          <span class="diff-strike">{{ c.from }}</span>
          <span class="diff-arrow">→</span>
          <span class="diff-new">{{ c.to }}</span>
          <span v-if="c.field !== 'designation'" class="diff-field">({{ c.field }})</span>
        </div>
      </div>
    </div>

    <!-- Definition changes -->
    <div v-if="diff.definitions" class="concept-diff-section">
      <span class="concept-diff-label">Definition changes</span>
      <div v-if="diff.definitions.changed?.length">
        <div v-for="(c, i) in diff.definitions.changed" :key="i" class="diff-defn">
          <div v-if="c.old" class="diff-strike diff-defn-text">{{ c.old }}</div>
          <div v-if="c.new" class="diff-new diff-defn-text">{{ c.new }}</div>
        </div>
      </div>
      <div v-if="diff.definitions.added?.length" class="concept-diff-added">
        <div v-for="(d, i) in diff.definitions.added" :key="i" class="diff-new diff-defn-text">{{ d }}</div>
      </div>
    </div>

    <!-- Note changes -->
    <div v-if="diff.notes" class="concept-diff-section">
      <span class="concept-diff-label">Note changes</span>
      <div v-if="diff.notes.added?.length" class="concept-diff-added">
        <div v-for="(n, i) in diff.notes.added" :key="'na-'+i" class="diff-new">+ {{ n }}</div>
      </div>
      <div v-if="diff.notes.removed?.length" class="concept-diff-removed">
        <div v-for="(n, i) in diff.notes.removed" :key="'nr-'+i" class="diff-strike">− {{ n }}</div>
      </div>
    </div>

    <!-- Example changes -->
    <div v-if="diff.examples" class="concept-diff-section">
      <span class="concept-diff-label">Example changes</span>
      <div v-if="diff.examples.added?.length" class="concept-diff-added">
        <div v-for="(e, i) in diff.examples.added" :key="'ea-'+i" class="diff-new">+ {{ e }}</div>
      </div>
      <div v-if="diff.examples.removed?.length" class="concept-diff-removed">
        <div v-for="(e, i) in diff.examples.removed" :key="'er-'+i" class="diff-strike">− {{ e }}</div>
      </div>
    </div>
  </div>
</template>

<style>
.concept-diff {
  margin: 0.5em 0;
  padding: 0.6em 0.8em;
  background: var(--color-paper-tint);
  border-radius: 4px;
  border-left: 3px solid var(--color-oiml-amber);
  font-size: 0.84rem;
}
.concept-diff-section {
  margin-bottom: 0.4em;
}
.concept-diff-label {
  display: block;
  font-size: 0.66rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-ink-muted);
  margin-bottom: 0.2em;
}
.diff-strike {
  text-decoration: line-through;
  color: var(--color-red);
}
.diff-new {
  color: var(--color-green);
}
.diff-arrow {
  margin: 0 0.4em;
  color: var(--color-ink-muted);
}
.diff-field {
  font-size: 0.75rem;
  color: var(--color-ink-muted);
  margin-left: 0.3em;
}
.diff-change-row {
  margin: 0.15em 0;
}
.diff-defn-text {
  margin: 0.2em 0;
  line-height: 1.45;
}
.concept-diff-added { margin: 0.15em 0; }
.concept-diff-removed { margin: 0.15em 0; }
</style>
