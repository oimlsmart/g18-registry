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
  const lines: string[] = [
    "flowchart TD",
    'A["Term used in<br/>OIML publications"]',
    'B{"Cites VIM/VIML?"}',
    'C{"Up to date?"}',
    'D["Nothing to do"]',
    'E["Update citation<br/>to latest"]',
    'G{"Still in<br/>VIM/VIML?"}',
    'H["Update resolves it"]',
    'I["Propose for<br/>V 1 / V 2 / V 3"]',
    'F{"Near-miss?"}',
    'J["Adopt V 1/V 2 term<br/>or propose V 3<br/>based on it"]',
    'K["Propose for V 3"]',
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

  // Determine the active path
  let activeNodes: string[] = ["A", "B"];
  if (isVim) {
    activeNodes.push("C");
    if (props.isCurrent) {
      activeNodes.push("D");
    } else if (props.latestCheckFound === true) {
      activeNodes.push("E", "G", "H");
    } else if (props.latestCheckFound === false) {
      activeNodes.push("E", "G", "I");
    }
  } else {
    activeNodes.push("F");
    if (props.hasNearMiss) {
      activeNodes.push("J");
    } else {
      activeNodes.push("K");
    }
  }

  // Style: active nodes get accent, others get muted
  lines.push("style A fill:#004996,stroke:#004996,color:#fff");
  for (const node of ["B", "C", "F", "G"]) {
    if (activeNodes.includes(node)) {
      lines.push(`style ${node} fill:#f0f6ff,stroke:#004996,color:#004996`);
    } else {
      lines.push(`style ${node} fill:#f1f5f9,stroke:#cbd5e1,color:#94a3b8`);
    }
  }
  for (const node of ["D", "E", "H", "I", "J", "K"]) {
    if (activeNodes.includes(node)) {
      if (node === "D") {
        lines.push(`style ${node} fill:#dcfce7,stroke:#6ee7b7,color:#064e3b`);
      } else if (["E", "I"].includes(node)) {
        lines.push(`style ${node} fill:#fef3c7,stroke:#fde68a,color:#92400e`);
      } else {
        lines.push(`style ${node} fill:#dbeafe,stroke:#93c5fd,color:#1e3a8a`);
      }
    } else {
      lines.push(`style ${node} fill:#f8fafc,stroke:#e2e8f0,color:#94a3b8`);
    }
  }

  return lines.join("\n");
}

async function render() {
  if (!container.value) return;
  try {
    const mermaid = (await import("mermaid")).default;
    mermaid.initialize({ startOnLoad: false, theme: "base", flowchart: { htmlLabels: true, curve: "basis" } });
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
</style>
