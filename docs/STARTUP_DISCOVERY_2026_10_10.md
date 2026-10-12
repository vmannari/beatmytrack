# Startup discovery — 2026-10-10

Requirements: START01 (no false empty state), START02 (startup prefetch), START03 (immediate compatible cached cards), RR06/V03/V05/B07/R01/Q01; preserve paging/search, account isolation, pinned racing contracts and public/artificial isolation.

The owner reports “No tracks found” appearing before Free Race's tracks load, and authorizes preloading during app startup. The carousel previously treated an unresolved catalog as an empty result. Beginning a paged query also replaced the existing cached index with an empty page list.

Discovery now starts during account/service initialization and again at startup completion. Identical pending requests coalesce, including when Free Race opens before the startup response arrives. This does not delay the account screen or startup completion on the full community catalog. Rivalry's existing independent prefetch remains intact.

The first **20 metadata cards** are persisted per query and server/account scope, with at most **three queries**, a **24-hour** age bound and the existing bounded atomic JSON cache. On restart, compatible cards and the actual previously returned total appear immediately while a new first page is fetched. Cached opaque server cursors are never reused. A successful fresh response replaces cached pages, including withdrawal or a confirmed empty response. Different filters/accounts do not hydrate the previous scoped page. An older public index can remain visible during the first upgraded app's default-query refresh; it is not used for filtered results or confirmed empty responses.

An uncached/unresolved list shows the existing “Loading tracks...” area. “No tracks found” appears only after the actual response confirms an empty result. Network errors retain their actionable error state. The previous empty/loading control is explicitly removed when paged cards arrive. The obsolete Connect prompt is suppressed while discovery is loading or cached cards are already present. No implementation/source labels or fabricated tracks/scores were added.

Preloading covers the first visible discovery page. It **does not download/compile every community track or fetch every histogram**: those remain bounded and selection-driven, with the preceding menu snapshot caches and metadata-first hero behavior. Artwork/fonts are already preloaded by the existing menu resources. Racing still requires the existing actual geometry/ticket checks; cached card metadata confers no competitive eligibility.

Changed files: `game/backend/discovery_pages.gd`, `game/backend/cloud_tracks.gd`, `game/ui/track_browser.gd`, `game/core/app.gd`; new regression `game/tests/test_startup_discovery.gd`; this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. No backend/runtime schema/deployment, canonical simulation, camera/art assets or player-record writes were changed. [Task-only checkpoint](evidence/startup-discovery-2026-10-10/scoped-change.patch) preserves prior/concurrent workspace changes.

Actual commands use pinned Godot **4.7.2 stable ed1daf0bf** through `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, isolated `APPDATA=build/startup-discovery-*-user`, and `BMT_STARTUP_EVIDENCE=docs/evidence/startup-discovery-2026-10-10`. Normal Windows certificate-store access was needed for engine startup.

| Actual command | Outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_startup_discovery.gd -Graphical -CommandTimeoutSeconds 90` | **21 checks, zero failures**; real app prefetch helper before menu activation, pending-read coalescing, cold/warm first frames, exact cached metadata JSON values, original total, fresh cursor, query/account fences, confirmed emptiness and three native captures |
| `TestScript -ScriptPath res://tests/test_discovery_pages.gd -CommandTimeoutSeconds 90` | **269 checks, zero failures**; 5,000-track paging, bounded eviction, search/favorites/random, stale-query fences, malformed page and explicit refresh; traversal **1733.436 ms** on this desktop fixture |
| `TestApp -CommandTimeoutSeconds 90` | **99 checks, zero failures**; existing menus, account storage, actual five-lap racing and PB persistence |
| `TestScript -ScriptPath res://tests/test_menu_loading.gd -CommandTimeoutSeconds 90` | **39 checks, zero failures**; compilation supersession, bounded cache, downloads, optional records and race availability |
| `TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 90` | **428 scripts, zero failures** |
| Scoped `git diff --check` and reverse checkpoint check | Pass |

Initial fixture assertions incorrectly compared typed in-memory metadata with JSON's numerical representation and included hidden diagnostic labels when checking visible UI. Those assertions now compare every metadata value through its actual JSON representation and inspect visible controls; no product requirement was relaxed. The final capture also removes the misleading Connect prompt from the warm list.

Inspected [uncached loading](evidence/startup-discovery-2026-10-10/cold-start-loading.png), [cached cards before the reply](evidence/startup-discovery-2026-10-10/warm-start-cards.png), and [confirmed empty search](evidence/startup-discovery-2026-10-10/confirmed-empty-search.png). These use the existing 5,000-track metadata fixture and delayed mock responses; they are not a live community screenshot, new races or shipping sample content.

No phone attachment check or physical-device test, Android export/install, full Validate, backend update or production action was performed. The fix is local client code and requires a rebuilt/restarted app. A genuinely uncached first launch must receive one metadata page before it can show real tracks; it never fabricates content or claims that unresolved data is empty. Remaining acceptance: actual device startup after cached/uncached login, service failures and account changes.
