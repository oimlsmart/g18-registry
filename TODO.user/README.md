# TODO.user — Concept Diff Integration + How to Use Pages

## What the user really wants

G 18 is a **working tool** for TC 1, not a reference. The user wants:

1. **Surfaces problems** — "Here are terms that need your attention"
2. **Shows evidence** — concept diffs showing WHAT changed between VIM editions
3. **Enables action** — propose, harmonize, upgrade citation
4. **Explains itself** — "How to use" pages with SVG flow diagrams per audience

## Audiences

| Audience | Goal | Primary page |
|---|---|---|
| TC 1 member | Audit terms, decide actions | /actions/ → term detail |
| Publication editor | Check TC/SC publications | /publications/{slug}/ |
| TC/SC project team | Review terms in their scope | /tc/{slug}/ |
| General user | Look up terms, understand status | /terms/{slug}/ |

## Work items

- [ ] 01-upgrade-glossarist-js.md — upgrade to 0.4.17 for concept diff API
- [ ] 02-concept-diff-view.md — render diffs in concept version series (designation changes, word-level definition diffs, note/example changes)
- [ ] 03-export-concept-diffs.md — pre-compute concept diffs in export pipeline so the frontend has structured diff data
- [ ] 04-how-to-use-page.md — create /how-to-use/ with SVG flow diagrams for each audience
- [ ] 05-audience-homepage.md — add audience cards to homepage linking to How to Use
