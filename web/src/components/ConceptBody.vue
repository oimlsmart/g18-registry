<script setup lang="ts">
import DefText from "./DefText.vue";

defineProps<{
  data: {
    designations?: { type: string; status: string; text: string }[];
    definitions?: string[];
    notes?: string[];
    examples?: string[];
  } | null;
}>();
</script>

<template>
  <div v-if="data" class="concept-body">
    <div v-if="data.designations?.length" class="full-concept-section">
      <span class="full-concept-label">Designations</span>
      <ul class="full-concept-designations">
        <li v-for="(d, i) in data.designations" :key="i">
          <span :class="['kind', `kind-${d.status}`]" style="margin-right:0.4em">{{ d.status }}</span>
          <DefText v-if="d.type === 'expression'" :text="d.text" />
          <code v-else>{{ d.text }}</code>
          <span v-if="d.type !== 'expression'" class="muted" style="margin-left:0.3em;font-size:0.8em">({{ d.type }})</span>
        </li>
      </ul>
    </div>
    <div v-if="data.definitions?.length" class="full-concept-section">
      <span class="full-concept-label">Definition</span>
      <p v-for="(def, i) in data.definitions" :key="i" class="authority-defn-body">
        <DefText :text="def" />
      </p>
    </div>
    <div v-if="data.notes?.length" class="full-concept-section">
      <span class="full-concept-label">Notes</span>
      <ol class="full-concept-list">
        <li v-for="(note, i) in data.notes" :key="i">
          <DefText :text="note" />
        </li>
      </ol>
    </div>
    <div v-if="data.examples?.length" class="full-concept-section">
      <span class="full-concept-label">Examples</span>
      <ol class="full-concept-list">
        <li v-for="(ex, i) in data.examples" :key="i">
          <DefText :text="ex" />
        </li>
      </ol>
    </div>
  </div>
</template>
