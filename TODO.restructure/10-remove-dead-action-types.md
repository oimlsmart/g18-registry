# 10 — Remove dead action types

## Context
Three action types are declared in the backend `Action::TYPES` and rendered in the frontend `ACTION_META`, but never actually produced by `Actions::Compiler`:

- `adopt_vim`    — was intended for "defined in VIML but VIM has it too"
- `adopt_viml`   — was intended for "defined in VIM but VIML has it too"
- `update_citation` — was reserved for Case 2 (historic match) but Case 2 was never implemented

Per the user's global rule "No half-finished implementations", these should be removed.

## Files to update
- `lib/g18/actions/action.rb` — remove from TYPES
- `lib/g18/actions.rb` — remove from docs comment
- `lib/g18/actions/compiler.rb` — remove from vocab_short lookup if present
- `web/src/composables/action-utils.ts` — remove from ACTION_META
- `web/src/islands/PublicationDetailPage.vue` — remove from type orders
- `web/src/islands/TcDetailPage.vue` — remove from type orders
- `web/src/islands/TermsListPage.vue` — remove from PRIORITY_ORDER
- `web/src/styles/components.css` — remove `.action-icon-adopt_*` rules
- `scripts/export_for_vite.rb` — remove from ACTION_PRIORITY map

## Out of scope
Case 2 (historic match detection) is a *feature* — tracked separately in TODO 18.
