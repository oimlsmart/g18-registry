// Loads and filters the vocab-gaps export. The export is pre-computed at
// build time (scripts/export_for_vite.rb) — this composable just wraps
// the JSON in a typed view and provides edition / search filters.

import { computed, ref } from "vue";
import gapsData from "@/data/vocab-gaps.json";

export interface VocabNearMiss {
  found: boolean;
  match_type: "exact" | "fuzzy";
  designation: string;
  concept_id: string;
  definition: string;
  similarity?: number;
  latest_label: string;
  url: string;
}

export interface VocabGap {
  slug: string;
  name: string;
  identifier: string;
  definitions: string[];
  publications: { publication_id: string; tc_sc: string; edition: string }[];
  editions_present: string[];
  near_misses: {
    vim: VocabNearMiss | null;
    viml: VocabNearMiss | null;
  };
}

export const vocabGaps = gapsData as unknown as VocabGap[];

export type GapScope = "no-match" | "viml-match" | "vim-match" | "all";

export function useVocabGaps() {
  const search = ref("");
  const scope = ref<GapScope>("no-match");
  const tcFilter = ref("");

  const allTCs = computed(() => {
    const s = new Set<string>();
    for (const g of vocabGaps) {
      for (const p of g.publications) if (p.tc_sc) s.add(p.tc_sc);
    }
    return Array.from(s).sort();
  });

  const filtered = computed(() => {
    let list: VocabGap[] = vocabGaps;
    if (scope.value === "no-match") {
      list = list.filter(g => !g.near_misses.vim && !g.near_misses.viml);
    } else if (scope.value === "viml-match") {
      list = list.filter(g => g.near_misses.viml);
    } else if (scope.value === "vim-match") {
      list = list.filter(g => g.near_misses.vim);
    }
    if (tcFilter.value) {
      list = list.filter(g => g.publications.some(p => p.tc_sc === tcFilter.value));
    }
    if (search.value) {
      const q = search.value.toLowerCase();
      list = list.filter(g => g.name?.toLowerCase().includes(q));
    }
    return list;
  });

  return { search, scope, tcFilter, allTCs, filtered };
}
