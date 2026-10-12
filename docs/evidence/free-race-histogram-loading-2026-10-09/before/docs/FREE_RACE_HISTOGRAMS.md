# Free Race histograms, 2026-10-09

Requirements: RR06/V03/V05/Q01; preserve R01 and the TD06/TD08 unified-comparison and public-isolation contracts. The owner requests histograms on every track with available comparison records, even without a personal time, and separate race/lap charts side by side.

`game/ui/track_browser.gd` now displays both existing server distributions with small Race/Lap labels. Charts retain every bin and add a player marker only when an actual local or verified time exists. The records panel grows from 160 to 180 logical pixels to accommodate the labels and complete time axes; each chart uses a 112-pixel minimum width so both fit on compact layouts. Empty distributions say “No times yet” instead of telling the player to set a time to unlock comparisons.

Reopening the already-selected cached track previously returned before loading comparison records. It now hydrates those records, including for drivers without a PB. Identical pending reads are coalesced; existing track, vehicle and selection guards remain. Prepared adjacent pages retain their no-network behavior. The existing results-comparison endpoint already returns both metrics without candidate times; no backend change or rollout is required.

Changed files: `game/ui/track_browser.gd`, `game/tests/test_unified_histograms.gd`, this document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. [Task-only Git patch](evidence/free-race-histograms-2026-10-09/scoped-change.patch) preserves the unrelated changes already in the workspace.

Actual commands use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned Godot **4.7.2 stable ed1daf0bf**, isolated `APPDATA=build/free-race-histograms-user-permitted` or `build/free-race-histograms-app-user`, and `BMT_RESULTS_EVIDENCE=docs/evidence/free-race-histograms-2026-10-09`:

- `TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical -CommandTimeoutSeconds 90`: **90 checks, zero failures**. Covers both metrics, local/verified markers, no personal record on three tracks, cached-track reopening, candidate-free requests, deduplicated pending reads, stable repeated data, forbidden captions and six screenshots. [Final log](evidence/free-race-histograms-2026-10-09/histograms-final.log).
- `TestApp -CommandTimeoutSeconds 90`: **99 checks, zero failures**. [Final log](evidence/free-race-histograms-2026-10-09/app-final.log).
- Scoped `git diff --check`: passes.

The cached-track regression was reproduced before its fix: **74 checks, one failure**, specifically the absent results-comparison read on cached reopening. Initial attempts hit restricted Windows certificate-store access, a missing copied fixture, chart clipping after adding labels, and an invalid hyphenated fixture ID; these were corrected without weakening the assertions. Native verification ran with permitted Windows certificate access and isolated saves.

Inspected captures: [no personal time, compact](evidence/free-race-histograms-2026-10-09/discovery-no-time-960x540.png), [with personal times](evidence/free-race-histograms-2026-10-09/discovery-1280x720.png). Both charts fit completely at **1280×720, 960×540 and 1600×720**, without overlap and with aligned baselines. The retained Silmukka fixture contains actual previously verified driver distributions and illustrative player UI values; the no-time case removes own-best/comparison fields and local records. It generates no races and writes no player/server records. Its sparse carousel and single public standings row are fixture setup, not a live discovery capture.

Limitations: comparison records still require the existing authenticated service access, or an already cached snapshot. Tracks with no recorded comparison times remain empty; no histogram samples or player markers are invented. No phone attachment check or physical-device test was performed. No Android export/install, full Validate, backend deployment or production action was performed. Remaining acceptance: owner/device visual review in the populated Free Race menu.
