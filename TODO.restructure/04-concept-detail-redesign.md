# 04 — Concept detail page redesign

## Context
The concept detail page (TermDetailPage.vue) needs a complete redesign. The authoritative V1/V2 concept should be the PRIMARY focus — everything else is compared against it.

## Layout priority (top to bottom)

### 1. Authoritative concept (V1 and/or V2) — MOST PROMINENT
- Full concept: ALL designations (preferred + admitted), definition (with xref linkification), notes (including examples within notes), examples
- Rich typography: italic Fraunces designation, definition cards, note blocks
- If concept exists in BOTH V1 and V2, show both side by side
- This is the anchor

### 2. Decision flow / recommendation
- Compact CSS flow chain showing which of the 5 cases applies
- Action buttons: "Adopt V1/V2", "Propose V3", "Compare V1/V2"
- "Compare V1/V2" opens glossarist-js concept comparison (definition diff)

### 3. Divergence summary across publications
- Group publications by definition variant
- Each group: definition text + list of publications using it
- Each pub entry: pub ID, clause, alignment case (1-5), G18 term ID chip
- Visual: card-based layout for BOTH multi-pub and single-pub groups (consistency)

### 4. Concept metadata
- G 18 entry IDs (2010, 202X) as chips
- Publication lifecycle status
- Source lineage / sourced_from

## Remove
- G 18 edition filter entirely
- Old edition-based publication instances table (replace with divergence summary)

## Files
- `web/src/islands/TermDetailPage.vue` — full redesign
- `web/src/components/DecisionFlowSVG.vue` — 5-case branching
- `web/src/components/ConceptBody.vue` — reuse for authoritative concept display
