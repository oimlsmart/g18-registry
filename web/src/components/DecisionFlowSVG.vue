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
  const lines: string[] = ["flowchart LR"];

  if (isVim) {
    lines.push('A["📊 OIML pubs"]');
    lines.push('B["✅ Cites V 1/V 2"]');
    if (props.isCurrent) {
      lines.push('C["✅ Up to date"]');
      lines.push('R["✅ Done"]');
      lines.push("A --> B --> C --> R");
    } else if (props.latestCheckFound === true) {
      lines.push('C["⚠️ Outdated"]');
      lines.push('R["🔄 Update to latest"]');
      lines.push("A --> B --> C --> R");
    } else if (props.latestCheckFound === false) {
      lines.push('C["⚠️ Outdated"]');
      lines.push('D["❌ Removed"]');
      lines.push('R["📝 Propose V 1/V 2/V 3"]');
      lines.push("A --> B --> C --> D --> R");
    } else {
      lines.push('C["❓ Check status"]');
      lines.push("A --> B --> C");
    }
  } else {
    lines.push('A["📊 OIML pubs"]');
    lines.push('B["❌ Not from V 1/V 2"]');
    if (props.hasNearMiss) {
      lines.push('C["🔍 Near-miss found"]');
      lines.push('R["📋 Adopt V 1/V 2<br/>or propose V 3"]');
      lines.push("A --> B --> C --> R");
    } else {
      lines.push('C["🔍 No match"]');
      lines.push('R["📝 Propose V 3"]');
      lines.push("A --> B --> C --> R");
    }
  }

  // Colors: blue start, neutral middle, accent result
  lines.push("classDef start fill:#004996,color:#fff,stroke:none");
  lines.push("classDef check fill:#f0f6ff,color:#004996,stroke:#89b4ef");
  lines.push("classDef warn fill:#fef3c7,color:#92400e,stroke:#fde68a");
  lines.push("classDef ok fill:#dcfce7,color:#064e3b,stroke:#6ee7b7");
  lines.push("classDef result fill:#dbeafe,color:#1e3a8a,stroke:#93c5fd");
  lines.push("class A start");
  lines.push("class B check");
  if (isVim) {
    if (props.isCurrent) { lines.push("class C ok"); lines.push("class R ok"); }
    else if (props.latestCheckFound === false) { lines.push("class C warn"); lines.push("class D warn"); lines.push("class R result"); }
    else { lines.push("class C warn"); lines.push("class R result"); }
  } else {
    lines.push("class C check");
    lines.push("class R result");
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
      themeVariables: {
        fontSize: "13px",
        fontFamily: "Hanken Grotesk, sans-serif",
        primaryColor: "#f0f6ff",
        primaryTextColor: "#0a1628",
        primaryBorderColor: "#89b4ef",
        lineColor: "#6b7a92",
      },
      flowchart: { htmlLabels: true, curve: "cardinal", padding: 8, nodeSpacing: 30, rankSpacing: 25 },
    });
    const id = `mf-${Math.random().toString(36).substring(2, 9)}`;
    const { svg } = await mermaid.render(id, buildGraph());
    container.value.innerHTML = svg;
  } catch {
    if (container.value) container.value.textContent = "";
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
  margin: 0.3em 0;
  overflow-x: auto;
}
.mermaid-container :deep(svg) {
  max-width: 100%;
  height: auto;
  max-height: 120px;
}
</style>
