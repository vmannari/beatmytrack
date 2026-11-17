# Reducing startup and race loading by 50 percent

The prepared-track prototype exceeds the 50% target for first-time Star/Pine/Rally race entry. Startup alone and cached restart do not yet meet that target. No shipping runtime changes are applied.

Requirements: HALF01 investigate a 50% startup reduction; HALF02 investigate a 50% first-race reduction; HALF03 keep cached restart, re-entry, actual rendering and the full launch journey visible; HALF04 preserve current geometry, canonical rules, ownership, memory limits and original readiness assertions.

## Proven first-race solution

Build exact road arrays, checkpoint layout, road support contours/bins and final scenery ahead of the player's first race. Ship prepared data for bundled/featured tracks and generate versioned artifacts during publication for other tracks. Keep the current validated construction fallback for absent or incompatible artifacts.

The private prototype reads the existing validated road, checkpoint and world formats from a trusted resource directory. World package reads use a read-only directory argument, bypassing the mutable user-cache publication lock while retaining its identity, checksum, resource/node/script whitelist and size checks. Existing user-cache writes and construction fallback remain. A small additional numeric artifact supplies support contours/bins; source identity, geometry key and checksum reject stale/corrupt support. Read generation is captured before disk I/O, so a concurrent trim cannot authorize repopulation with a newer generation.

| Actual App probe | Empty player cache | Prepared package, empty player cache | Reduction |
| --- | ---: | ---: | ---: |
| First matched prototype pair | 13.417 s | 4.823 s | 64.1% |
| Final generation-fenced prototype | 15.255 s | 4.767 s | 68.7% |
| Final repeat with engine-clock measurement | 14.930 s | 5.954 s | 60.1% |

Additional package first-entry observation: 5.115 s. These are fresh private profiles, with existing project imports and OS/driver caches. The final package contains six active files totaling **6,591,015 bytes**: approximately 2.08 MB road arrays, 70.8 KB checkpoints, 20.9 KB support data and 4.42 MB world plus manifest/checksum files. Prepared scenery is engine/renderer/platform specific; numeric assets also require their existing geometry, compiler, precision and rule identities.

The package consumer does no road/scenery construction on first entry. Checkpoint preparation drops from seconds to 58–76 ms in package samples. Fresh-process support construction, previously 769 ms in the unmodified disk-hit control, becomes 2.7–4.1 ms of prepared support work. The same resident memory limits remain; disk/package admission still needs complete production lifecycle qualification.

The real App releases its loading cover only after preparation, at simulation tick zero, with five laps and the full 360-tick countdown. The unchanged fixture checks pass. This is actual installed race readiness, not an earlier progress-screen milestone. No car simplification, quality reduction or skipped render stage contributes to the result.

## Full journey qualification

Do not call the entire startup-to-race journey halved. One earlier interval, measured from App scene loading through race readiness, falls from 16.963 to 8.315 seconds, or 51.0%. That timer excludes preceding engine/autoload initialization.

The final probe explicitly includes that preceding engine-clock interval: **20.845 to 12.453 seconds, a 40.3% reduction**. Race entry in those same processes improves by 60.1%. Small local samples vary with concurrent machine activity. The package solution therefore clears HALF02 in the measured fixture; it does not clear HALF01 or the complete launch journey at 50%.

## Startup needs a real ownership and dependency split

The current-source startup control is 4.970 seconds to a drawn offline account menu. Halving it requires 2.485 seconds or less. The previous review's 5.479-second observation is historical context, not the denominator for the new candidate comparisons.

Simple method-level lazy loading produces 4.432 seconds: only 10.8% faster in that sample. Its scene graph shrinks from 2.694 to 1.299 seconds, but initialization grows from 182 ms to 1.123 seconds. Broader compiler/simulation reference deferral and audio laziness do not establish a further saving. These candidates are not sufficient.

A separate architecture-sizing probe builds the real current AccountController and AccountPanel without App. Observations are 3.069 seconds, 2.758 seconds after additional boundaries, and 3.454 seconds with a further decoder-laziness experiment. Even the best is only 44.5% below the new startup control. The probe deliberately has no completed application handoff; it is not a production-ready replacement or a qualified startup win.

The implementation to investigate is a small bootstrap that owns saved settings, language, menu/UI audio and account restoration, followed by feature controllers that remain separate throughout the session. In particular:

- Separate LocalRecords settings/loading from race scoring, physics identity and compiler-dependent recording helpers. Preserve the existing file/schema and owner selection behavior.
- Separate menu/UI audio from dormant driving-score/pace/session dependencies. Merely changing eager creation to a getter was insufficient; a menu-process access immediately reloaded that graph.
- Keep default-track construction, editor state and non-account backend composition out of the account bootstrap. Resolve the exact active owner's selected track when it is needed.
- Keep the original App monolith out of the handoff. Showing the account page quickly and loading that same monolith on the next action would move the wait.

Acceptance must include guest continuation, restored sign-in, profile removal/sign-out, selected-owner records/track, tutorial entry and first race. A first account screenshot alone cannot establish a 50% complete-startup improvement. The current architecture-sizing prototype is still 273 ms above the strict new startup target, before qualifying handoff.

## Cached restarts require a second reduction

The unmodified current-source disk-hit control is 5.533 seconds, so its 50% target is 2.767 seconds. Package entries remain 4.767–5.954 seconds. Packaging avoids first-time construction but does not halve an already cached restart.

About 2.6–3.2 seconds still goes to the race/Game resource graph. A prototype splitting results/publication methods into lazy wrappers leaves race feature loading around 1.8 seconds and does not improve the cold race control. The remaining start path still resolves shared heavy dependencies. A smaller controller file alone is insufficient.

To meet the cached target, support persistence must be combined with a materially smaller runtime graph: shared lightweight data contracts, actual optional-feature boundaries and prepared consumers that do not resolve construction/unused presentation dependencies. The measured graph would need to approach roughly 0.8–1.0 seconds, with the other preparation stages held steady. That is a target budget, not a demonstrated result. Source-tree identity hashing also costs about 0.4–0.5 seconds here, but exported builds already use their packaged build identity, so that must not be claimed as a new release optimization.

Godot's pinned export code produces token buffers, rather than a persistent cache of fully analyzed/compiled script execution. Changing scripts to binary tokens alone is not evidence that this graph cost disappears. [Pinned export implementation](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gdscript/register_types.cpp), [pinned script-loading implementation](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/gdscript/gdscript_resource_format.cpp).

## Night and warm re-entry

The prior review's first Night/Kart start is 24.499 seconds and includes 7.717 seconds in night-lighting/restored-finish preparation. Night persistent world caching remains disabled by an existing qualification gate. This review neither lifts that gate nor measures a 50% Night improvement.

Night needs its own workstream: qualify exact scene restoration, then investigate reducing redundant shader/material preparation across the same required four lighting contexts. Keep the current appearance, clean/weathered material behavior and real completion checks. Device/renderer-specific shader behavior prevents treating the Pine package result as a Night guarantee.

Same-process re-entry already takes roughly 0.3 seconds for Pine and 0.6 seconds for Night. A bounded retained ready Game, keyed by exact owner/track/car/appearance/graphics state, is the next candidate. Existing in-place retry demonstrates 11–18 ms reuse in the latest package probes. Keeping Game across navigation is not implemented here; retained memory, cancellation, account transitions and pending effects would need qualification.

## Recommended implementation order

1. Implement the prepared artifact producer and read-only consumer first. Use the existing BundledTracks content-hash manifest as the discovery boundary, extending it with exact component identities. Start with bundled/featured tracks. Preserve original cache limits, compatible fallback and all untrusted-input checks.
2. Move support persistence behind the existing preparation worker/admission boundary. The prototype writes a private numeric cache for measurement; production must add atomic publication, disk bounds, cancellation and source/build-version migration without adding file I/O to canonical simulation or the ordinary RAM cache API.
3. Refactor bootstrap and runtime dependency ownership together. Measure first drawn menu, functional continuation, cached race entry and engine-to-race, using the same target denominator. Set HALF01/HALF03 complete only on measured 50% results.
4. Qualify Night scene persistence and lighting preparation separately. Retain its rejection gate until exact controls pass.
5. Evaluate ready-Game retention for warm navigation under the existing memory budget. Car mesh reduction is a lower loading priority than these measured costs.

Publication/download time belongs in the online journey. A 6.6 MB artifact can trade CPU savings for bandwidth; package known tracks at installation and measure actual network cost before extending this to arbitrary downloads. Do not silently add cache production to player startup.

## Verification and source scope

All mutations to existing runtime sources occur only in the private build snapshot. New task tools/probes and this report are the repository changes. No shipping runtime, model, handling, quality setting, save schema, backend contract or service is authored by the review.

Before/after source fences, raw output, process commands, package component hashes, architecture attempts and failure receipts are in [the evidence directory](evidence/loading-half-review-2026-11-17/). The final native package fixture passes 19/0; final numeric support round-trip/rejection controls pass 9/0, including exact ordered encoded contours/bins, corrupted checksum/source/key, and stale-generation writer rejection. Earlier cold/package fixtures and all failures are retained. Full driving/replay, broad cache corruption, Android, network and production handoff qualification remain.

Across 23 recorded attempts, 21 complete successfully with stable measured sources and no engine diagnostics. Successful fixtures total 209 checks; two rejected attempts retain their compiler/fixture failures. The six-file private candidate patch applies and reverses exactly after LF normalization; its generated module retains a trailing-blank-line patch warning. The warning is not a functional or performance qualification.

Initial controls include a private-copy missing-new-editor-helper failure, corrected by copying newly added source inputs, and a generated wrapper missing a bool return, corrected without weakening any assertion. App lazy loading, broad contract deferral, audio laziness, decoder laziness and the results-module split are kept as insufficient/negative evidence. A later support-read audit captures the generation before disk I/O; final seed/package and headless controls cover that correction.

The pinned engine is official Godot 4.7.2 `ed1daf0bf`, desktop Compatibility on RTX 3090 at 1280×720, private profiles, explicitly disabled backend, Dummy audio and music disabled. Native probes run sequentially. Existing imports and OS/driver caches remain; this is not a first-install or Android guarantee. Other workspace work continued. No device query/test, export, deployment, owner-save/process action or shared-index staging is performed. Standard build retention applies; no permanent project-copy pin is added.

Completion retention succeeds: 30.29 to 30.05 GiB, two entries removed. Recent, protected or locked output remains above the 20 GiB target. Scoped prototype sources, commands, hashes and receipts are preserved separately from disposable project copies and cache payloads.
