# TC/SC attribution for OIML publications

This directory holds the registry's local copy of OIML publication
bibliography enriched with **Technical Committee / Subcommittee** (TC/SC)
attribution.

## Files

- `publications.yaml` — one entry per OIML publication cited by G 18 (88
  total). Each entry has `id`, `reference`, `link` (mirrored from
  `oimlsmart/vocab` `datasets/g18/bibliography.yaml`) plus a `tc_sc` field
  and a free-form `notes` field.

## Source of truth

| Layer | Location | Role |
|---|---|---|
| Upstream bibliography | `oimlsmart/vocab` `datasets/g18/bibliography.yaml` | Canonical for `id`, `reference`, `link` |
| TC/SC attribution | this file (`tc-sc/publications.yaml`) | Canonical for `tc_sc`, `notes` |
| Migration consumer | `scripts/migrate_from_vocab.rb` | Reads `tc-sc/publications.yaml` to populate `data/*.yaml` `publications[*].tc_sc` |

## Workflow

When the upstream vocab bibliography changes (new publication, updated
link, etc.):

```bash
scripts/sync_tc_sc.rb      # re-mirror, preserving existing tc_sc values
scripts/validate_tc_sc.rb  # verify local in sync with upstream
scripts/migrate_from_vocab.rb  # rebuild data/ with new bib
```

When OIML central secretariat confirms a TC/SC attribution, edit
`publications.yaml` directly and re-run the migration:

```bash
$EDITOR tc-sc/publications.yaml    # fill in tc_sc for the publication(s)
scripts/validate_tc_sc.rb          # report current coverage
scripts/migrate_from_vocab.rb      # rebuild data/
```

## Convention

```yaml
tc_sc: ""                  # not yet attributed; awaiting OIML confirmation
tc_sc: "TC 9"              # single TC
tc_sc: "TC 9/SC 1"         # TC with subcommittee
tc_sc: "TC 9; TC 10"       # multiple TCs (semicolon-separated)
notes: "Confirmed by secretariat 2026-02-15"  # free-form source/caveat
```

## Open questions

These need OIML central secretariat input before the data is complete:

1. **Authoritative source.** What is the canonical record of which TC/SC
   owns each OIML publication? Candidates: the secretariat's internal
   publication register; the OIML website publication pages; the foreword
   of each publication itself.
2. **Multi-TC publications.** Some publications have content contributed by
   more than one TC. Do we record one (primary), all, or a "lead TC + contributing TCs" distinction?
3. **Dead TCs.** TCs that no longer exist (e.g. TCs merged or disbanded).
   Use the TC name as it was at time of publication, or remap to the current TC?
4. **Historical (pre-2000) publications.** Some old publications have
   uncertain TC/SC attribution. Mark with `notes: "pre-2000, uncertain"`?
5. **Edition-level vs publication-level.** Some TC/SC responsibility shifts
   between editions (e.g., TC X owns the 1986 edition but TC Y owns the
   2004 revision). One row per `OIML-id:year`, or one row per
   publication-lineage?

## Coverage status

As of the last sync, see `scripts/validate_tc_sc.rb` output for the
populated/blank count. Until OIML provides attribution, most entries have
`tc_sc: ""` — the per-TC/SC browsing view (TODO 04) will still render, but
group terms only by the publications that DO have a TC/SC.
