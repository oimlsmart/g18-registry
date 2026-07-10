# 13: Proposals (`/proposals/`)

Port `web/src/pages/vocab-gaps.vue` → `src/pages/proposals.astro`:
- Sticky scope filter (V 3 candidates / V 1/V 2 candidates / All)
- Search + TC filter
- Desktop table: Term, Near-miss (clickable links to vocab site), Pubs, Definition, Propose
- Mobile card layout
- Pagination
- Proposal modal: target radio (conceptual categories), rationale, GitHub issue button
- composeIssueBody + SHA-256 checksum via Web Crypto API
