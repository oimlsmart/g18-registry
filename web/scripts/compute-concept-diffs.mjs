#!/usr/bin/env node

import { readConcepts } from "glossarist/concept";
import { diffConcepts } from "glossarist";

const oldDir = process.argv[2];
const newDir = process.argv[3];

if (!oldDir || !newDir) {
  console.error("Usage: compute-concept-diffs.mjs <old-concept-dir> <new-concept-dir>");
  process.exit(1);
}

const oldConcepts = readConcepts(oldDir);
const newConcepts = readConcepts(newDir);

const oldMap = new Map(oldConcepts.map(c => [c.id, c]));
const newMap = new Map(newConcepts.map(c => [c.id, c]));

const diffs = {};

for (const [id, newConcept] of newMap) {
  const oldConcept = oldMap.get(id);
  if (!oldConcept) continue;
  const diff = diffConcepts(oldConcept, newConcept, "eng");
  if (diff.hasChanges) {
    diffs[id] = summarizeDiff(diff);
  }
}

process.stdout.write(JSON.stringify(diffs));

function summarizeDiff(diff) {
  const summary = {};

  if (diff.designations?.hasChanges) {
    summary.designations = {};
    if (diff.designations.added?.length) {
      summary.designations.added = diff.designations.added.map(a => a.value?.designation || a);
    }
    if (diff.designations.removed?.length) {
      summary.designations.removed = diff.designations.removed.map(r => r.value?.designation || r);
    }
    if (diff.designations.changed?.length) {
      summary.designations.changed = diff.designations.changed.map(c => ({
        from: c.oldValue?.designation || c.old,
        to: c.newValue?.designation || c.new,
        field: c.field || "normative_status",
      }));
    }
  }

  if (diff.definitions?.hasChanges) {
    summary.definitions = {};
    if (diff.definitions.changed?.length) {
      summary.definitions.changed = diff.definitions.changed.map(c => ({
        old: c.oldValue?.content || c.old,
        new: c.newValue?.content || c.new,
      }));
    }
    if (diff.definitions.added?.length) {
      summary.definitions.added = diff.definitions.added.map(a => a.value?.content || a);
    }
    if (diff.definitions.removed?.length) {
      summary.definitions.removed = diff.definitions.removed.map(r => r.value?.content || r);
    }
  }

  if (diff.notes?.hasChanges) {
    summary.notes = {};
    if (diff.notes.added?.length) summary.notes.added = diff.notes.added.map(a => a.value?.content || a);
    if (diff.notes.removed?.length) summary.notes.removed = diff.notes.removed.map(r => r.value?.content || r);
    if (diff.notes.changed?.length) {
      summary.notes.changed = diff.notes.changed.map(c => ({
        old: c.oldValue?.content || c.old,
        new: c.newValue?.content || c.new,
      }));
    }
  }

  if (diff.examples?.hasChanges) {
    summary.examples = {};
    if (diff.examples.added?.length) summary.examples.added = diff.examples.added.map(a => a.value?.content || a);
    if (diff.examples.removed?.length) summary.examples.removed = diff.examples.removed.map(r => r.value?.content || r);
    if (diff.examples.changed?.length) {
      summary.examples.changed = diff.examples.changed.map(c => ({
        old: c.oldValue?.content || c.old,
        new: c.newValue?.content || c.new,
      }));
    }
  }

  return summary;
}
