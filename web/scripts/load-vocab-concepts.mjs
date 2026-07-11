#!/usr/bin/env node

import { readConcepts } from "glossarist/concept";

const dir = process.argv[2];
const mode = process.argv[3] || "index";

if (!dir) {
  console.error("Usage: load-vocab-concepts.mjs <concept-dir> [index|full]");
  process.exit(1);
}

const concepts = readConcepts(dir);

if (mode === "full") {
  const out = {};
  for (const c of concepts) {
    const entry = {};
    for (const lang of c.languages) {
      const loc = c.localization(lang);
      if (!loc) continue;
      entry[lang] = {
        designations: (loc.terms || []).map((t) => ({
          type: t.type,
          status: t.normativeStatus,
          text: t.designation,
        })),
        definitions: (loc.definitions || []).map((d) => d.content).filter(Boolean),
        notes: (loc.notes || []).map((d) => d.content).filter(Boolean),
        examples: (loc.examples || []).map((d) => d.content).filter(Boolean),
      };
    }
    out[c.id] = entry;
  }
  process.stdout.write(JSON.stringify(out));
} else {
  const idx = {};
  for (const c of concepts) {
    const loc = c.localization("eng");
    if (!loc) continue;
    const pref = loc.terms?.find((t) => t.normativeStatus === "preferred") || loc.terms?.[0];
    if (!pref?.designation) continue;
    const defn = loc.definitions?.map((d) => d.content).filter(Boolean).join("\n").trim();
    idx[pref.designation.toLowerCase().trim()] = { id: c.id, definition: defn || "" };
  }
  process.stdout.write(JSON.stringify(idx));
}
