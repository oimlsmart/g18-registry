<script setup lang="ts">
import { ref, onMounted, watch } from "vue";

const props = defineProps<{
  kind: string;
  isCurrent: boolean;
  isSuperseded: boolean;
  latestCheckFound: boolean | null;
  hasNearMiss: boolean;
}>();

const container = ref<HTMLElement>();

function buildGraph(): string {
  const isVim = props.kind !== "oiml_original" && props.kind !== "undefined";

  const active = new Set<string>(["A", "B"]);
  if (isVim) {
    active.add("C");
    if (props.isCurrent) {
      active.add("D");
    } else if (props.latestCheckFound === true) {
      active.add("E", "G", "H");
    } else if (props.latestCheckFound === false) {
      active.add("E", "G", "I");
    }
  } else {
    active.add("F");
    if (props.hasNearMiss) {
      active.add("J");
    } else {
      active.add("K");
    }
  }

  const isActive = (id: string) => active.has(id);

  const lines: string[] = [
    "flowchart TD",
    'A["Term in OIML pubs"]',
    'B{"VIM/VIML?"}',
    'C{"Current?"}',
    'D["Done"]',
    'E["Update citation"]',
    'G{"In latest?"}',
    'H["Resolved"]',
    'I["Propose V1/V2/V3"]',
    'F{"Near-miss?"}',
    'J["Adopt or propose V3"]',
    'K["Propose V3"]',
    "A --> B",
    'B -->|"Yes"| C',
    'B -->|"No"| F',
    'C -->|"Yes"| D',
    'C -->|"No"| E',
    "E --> G",
    'G -->|"Yes"| H',
    'G -->|"No"| I',
    'F -->|"Yes"| J',
    'F -->|"No"| K',
  ];

  // Inactive nodes: faded out so the active path stands out
  for (const id of ["A","B","C","D","E","F","G","H","I","J","K"]) {
    if (isActive(id)) {
      if (id === "A") {
        lines.push(`class ${id} entryActive`);
      } else if (["B","C","F","G"].includes(id)) {
        lines.push(`class ${id} decisionActive`);
      } else if (id === "D" || id === "H") {
        lines.push(`class ${id} doneActive`);
      } else if (["E","I"].includes(id)) {
        lines.push(`class ${id} warnActive`);
      } else {
        lines.push(`class ${id} actionActive`);
      }
    } else {
      lines.push(`class ${id} inactive`);
    }
  }

  return lines.join("\n");
}

async function render() {
  if (!container.value) return;
  try {
    const mermaid = (await import("mermaid")).default;
    mermaid.initialize({
      startOnLoad: false,
      theme: "base",
      flowchart: { htmlLabels: true, curve: "basis", nodeSpacing: 20, rankSpacing: 25 },
    });
    const id = `mf-${Math.random().toString(36).substring(2, 9)}`;
    const { svg } = await mermaid.render(id, buildGraph());
    container.value.innerHTML = svg;
  } catch {
    if (container.value) container.value.textContent = "Decision flow unavailable";
  }
}

onMounted(render);
watch(() => [props.kind, props.isCurrent, props.isSuperseded, props.latestCheckFound, props.hasNearMiss], render);
</script>

<template>
  <div ref="container" class="mermaid-container"></div>
</template>

<style scoped>
.mermaid-container {
  display: flex;
  justify-content: center;
  margin: 0.5em 0;
  overflow-x: auto;
}
.mermaid-container :deep(svg) {
  max-width: 100%;
  height: auto;
}

/* Compact nodes — reduce internal padding so boxes are smaller */
.mermaid-container :deep(.node rect),
.mermaid-container :deep(.node polygon) {
  rx: 4px;
  ry: 4px;
}

/* Active styles: strong borders + bold text so they pop */
.mermaid-container :deep(.entryActive rect) {
  fill: #004996 !important;
  stroke: #004996 !important;
  stroke-width: 2px !important;
}
.mermaid-container :deep(.entryActive text) {
  fill: #fff !important;
  font-weight: 700 !important;
}

.mermaid-container :deep(.decisionActive rect) {
  fill: #dbeafe !important;
  stroke: #004996 !important;
  stroke-width: 2.5px !important;
}
.mermaid-container :deep(.decisionActive text) {
  fill: #004996 !important;
  font-weight: 700 !important;
}

.mermaid-container :deep(.doneActive rect) {
  fill: #dcfce7 !important;
  stroke: #16a34a !important;
  stroke-width: 2.5px !important;
}
.mermaid-container :deep(.doneActive text) {
  fill: #064e3b !important;
  font-weight: 700 !important;
}

.mermaid-container :deep(.warnActive rect) {
  fill: #fef3c7 !important;
  stroke: #d97706 !important;
  stroke-width: 2.5px !important;
}
.mermaid-container :deep(.warnActive text) {
  fill: #92400e !important;
  font-weight: 700 !important;
}

.mermaid-container :deep(.actionActive rect) {
  fill: #dbeafe !important;
  stroke: #2563eb !important;
  stroke-width: 2.5px !important;
}
.mermaid-container :deep(.actionActive text) {
  fill: #1e3a8a !important;
  font-weight: 700 !important;
}

/* Inactive: faded gray so the active path is obvious */
.mermaid-container :deep(.inactive rect) {
  fill: #f8fafc !important;
  stroke: #e2e8f0 !important;
  stroke-width: 1px !important;
}
.mermaid-container :deep(.inactive text) {
  fill: #cbd5e1 !important;
  font-weight: 400 !important;
}
.mermaid-container :deep(.inactive) {
  opacity: 0.55;
}

/* Active edges: bolder; inactive edges: faint */
.mermaid-container :deep(.edgePath .path) {
  stroke-width: 1.5px;
}
</style>
