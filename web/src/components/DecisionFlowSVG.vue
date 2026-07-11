<script setup lang="ts">
defineProps<{
  kind: string;
  isCurrent: boolean;
  isSuperseded: boolean;
  latestCheckFound: boolean | null;
  hasNearMiss: boolean;
}>();
</script>

<template>
  <svg viewBox="0 0 620 400" class="decision-flow-svg" xmlns="http://www.w3.org/2000/svg">
    <!-- Start node -->
    <rect x="200" y="10" width="220" height="36" rx="6" fill="var(--color-accent)" />
    <text x="310" y="33" text-anchor="middle" fill="#fff" font-size="12" font-weight="600">Term used in OIML publications</text>

    <!-- Arrow down -->
    <line x1="310" y1="46" x2="310" y2="60" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <polygon points="305,58 310,66 315,58" fill="var(--color-ink-muted)" />

    <!-- Decision: Does it cite VIM/VIML? -->
    <polygon points="310,66 440,110 310,154 180,110" fill="var(--color-paper-tint)" stroke="var(--color-rule)" stroke-width="1.5" />
    <text x="310" y="107" text-anchor="middle" font-size="11" font-weight="600" fill="var(--color-ink)">Cites VIM/VIML?</text>

    <!-- YES branch (left) -->
    <line x1="180" y1="110" x2="120" y2="110" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <line x1="120" y1="110" x2="120" y2="170" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <polygon points="115,168 120,176 125,168" fill="var(--color-ink-muted)" />
    <text x="150" y="104" font-size="10" font-weight="600" fill="var(--color-green)">YES</text>

    <!-- Decision: Is citation up to date? -->
    <polygon points="120,176 220,210 120,244 20,210" fill="var(--color-paper-tint)" stroke="var(--color-rule)" stroke-width="1.5" />
    <text x="120" y="207" text-anchor="middle" font-size="10" font-weight="600" fill="var(--color-ink)">Up to date?</text>

    <!-- YES → Nothing to do -->
    <line x1="20" y1="210" x2="10" y2="210" stroke="var(--color-green)" stroke-width="2" />
    <line x1="10" y1="210" x2="10" y2="270" stroke="var(--color-green)" stroke-width="2" />
    <rect x="-40" y="270" width="100" height="30" rx="4" :fill="isCurrent && !isSuperseded ? 'var(--status-ok-bg)' : 'none'" :stroke="isCurrent && !isSuperseded ? 'var(--status-ok-border)' : 'var(--color-rule)'" stroke-width="1" />
    <text x="10" y="289" text-anchor="middle" font-size="10" font-weight="600" :fill="isCurrent && !isSuperseded ? 'var(--status-ok-text)' : 'var(--color-ink-muted)'">Nothing to do</text>

    <!-- NO → Update citation -->
    <line x1="120" y1="244" x2="120" y2="270" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <polygon points="115,268 120,276 125,268" fill="var(--color-ink-muted)" />
    <text x="135" y="258" font-size="10" font-weight="600" fill="var(--color-oiml-amber)">NO</text>

    <!-- Decision: Still in VIM/VIML? -->
    <polygon points="120,276 220,310 120,344 20,310" fill="var(--color-paper-tint)" stroke="var(--color-rule)" stroke-width="1.5" />
    <text x="120" y="307" text-anchor="middle" font-size="10" font-weight="600" fill="var(--color-ink)">Still exists?</text>

    <!-- Still exists YES → Update -->
    <line x1="20" y1="310" x2="10" y2="310" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <line x1="10" y1="310" x2="10" y2="370" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <!-- (overlaps with Nothing to do box for simplicity) -->

    <!-- Still exists NO → Propose -->
    <line x1="120" y1="344" x2="120" y2="370" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <rect x="70" y="370" width="120" height="26" rx="4" :fill="latestCheckFound === false ? 'var(--status-warn-bg)' : 'none'" :stroke="latestCheckFound === false ? 'var(--status-warn-border)' : 'var(--color-rule)'" stroke-width="1" />
    <text x="130" y="387" text-anchor="middle" font-size="10" font-weight="600" :fill="latestCheckFound === false ? 'var(--status-warn-text)' : 'var(--color-ink-muted)'">Propose for V 1/V 2/V 3</text>

    <!-- NO branch (right) - OIML original -->
    <line x1="440" y1="110" x2="500" y2="110" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <line x1="500" y1="110" x2="500" y2="170" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <polygon points="495,168 500,176 505,168" fill="var(--color-ink-muted)" />
    <text x="450" y="104" font-size="10" font-weight="600" fill="var(--color-oiml-amber)">NO</text>

    <!-- Decision: Resembles VIM/VIML? -->
    <polygon points="500,176 610,210 500,244 390,210" fill="var(--color-paper-tint)" stroke="var(--color-rule)" stroke-width="1.5" />
    <text x="500" y="207" text-anchor="middle" font-size="10" font-weight="600" fill="var(--color-ink)">Near-miss?</text>

    <!-- YES → Adopt or Propose V3 -->
    <line x1="500" y1="244" x2="500" y2="270" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <polygon points="495,268 500,276 505,268" fill="var(--color-ink-muted)" />
    <rect x="430" y="270" width="140" height="30" rx="4" :fill="hasNearMiss ? 'var(--status-info-bg)' : 'none'" :stroke="hasNearMiss ? 'var(--status-info-border)' : 'var(--color-rule)'" stroke-width="1" />
    <text x="500" y="289" text-anchor="middle" font-size="10" font-weight="600" :fill="hasNearMiss ? 'var(--status-info-text)' : 'var(--color-ink-muted)'">Adopt or Propose V 3</text>

    <!-- NO → Propose V3 -->
    <line x1="610" y1="210" x2="620" y2="210" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <line x1="620" y1="210" x2="620" y2="270" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <line x1="620" y1="270" x2="570" y2="270" stroke="var(--color-ink-muted)" stroke-width="1.5" />
    <text x="600" y="264" font-size="10" fill="var(--color-ink-muted)">NO</text>

    <!-- Legend -->
    <rect x="430" y="330" width="160" height="60" rx="4" fill="none" stroke="var(--color-rule-soft)" stroke-width="1" />
    <text x="440" y="346" font-size="9" font-weight="600" fill="var(--color-ink-muted)">Legend</text>
    <rect x="440" y="352" width="12" height="10" :fill="kind === 'oiml_original' ? 'var(--status-warn-bg)' : 'var(--status-ok-bg)'" stroke="var(--color-rule)" stroke-width="0.5" />
    <text x="458" y="361" font-size="9" fill="var(--color-ink-soft)">Your term is here</text>
    <rect x="440" y="370" width="12" height="10" fill="none" stroke="var(--color-rule)" stroke-width="0.5" />
    <text x="458" y="379" font-size="9" fill="var(--color-ink-muted)">Other paths</text>
  </svg>
</template>

<style scoped>
.decision-flow-svg {
  width: 100%;
  max-width: 620px;
  height: auto;
  overflow: visible;
}
</style>
