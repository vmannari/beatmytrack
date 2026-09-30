# Premium Race Complete presentation

2026-09-30. Requirements V03/V04 (post-race presentation), R01 (actual race metrics), B19 (verified comparison), Q01 (verification); owner Race Complete reference.

Rewards occupy the left panel with unboxed eligible reasons, gold amounts, sequential reveal and a prominent gold total. Existing preview eligibility and amounts are preserved: completion, clean race, race PB and flying-lap PB appear only when eligible. Provisional rewards do not write currency, so the preview/no-credit label remains visible. No invented first-visit or percentile rewards.

Where You Stand uses adjacent race-time and best-lap columns, precise PB differences and distributions with highlighted markers, time axes and source labels. Matching milliseconds show Matches your PB and share a bin. For cloud races the existing version/vehicle leaderboard, histogram and around-me endpoints supply actual verified-player counts, rank and marker. These describe verified PBs, which may differ from the completed race time above. A pending upload has no player marker. Empty or unavailable online data retains clearly labeled local context: this race plus the previous PB. Best lap shows actual valid flying laps from this race; no global lap percentile is fabricated because that backend metric does not exist. One/few samples legitimately produce sparse charts.

Next Tracks uses the existing cleared biome artwork from TrackTile, actual track silhouettes, ratings with their existing local/cloud provenance, five-lap estimates and a gold selected-card frame. Artwork is illustrative biome scenery rather than a screenshot of each circuit. The selected name drives the large Race action. Results, Tracks/editor and Home transitions remain wired. No cosmetic Popular/New filters with fabricated feeds were added.

Changed files: `game/ui/race_complete.gd`, `game/ui/track_distribution.gd`, `game/tests/test_race_results.gd`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and the dated screenshot evidence. No gameplay physics, reward economy, new assets or backend schema changes.

Actual commands and results:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestResults`: 482 checks, zero failures after adding distribution regression coverage.
- `$env:BMT_RESULTS_EVIDENCE = 'C:/Codes/Godot/Beat my track/docs/evidence/race-complete-2026-09-30'`; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureResults`: final 500 checks, zero failures, Godot 4.7.2 Compatibility.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus`: 26 checks, zero failures.
- `git diff --check`: passed.
- `C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe devices`: no attached devices.

Tests retain reward eligibility/reveal/total, rating persistence, selected next-track launch, Results/Home transitions, and viewport containment at 1280x720, 1920x1080 and 2400x1080. New deterministic client fixtures exercise exact server bin counts, canonical-tick conversion, exclusive bin edges, population labels and pending player placement; local fixtures cover empty samples and rounding. These are test fixtures, not production ranking data. A new live HTTP/backend end-to-end test was not run for this presentation slice.

Initial runs exposed an overflowing vertical minimum size; reduced chart/card minimum heights and outer recommendation padding, retaining all actions. Final [1280x720](evidence/race-complete-2026-09-30/race-complete-1280x720.png) and [wide screen](evidence/race-complete-2026-09-30/race-complete-2400x1080.png) captures inspected. [Reward reveal](evidence/race-complete-2026-09-30/reward-reveal-first.png) also retained.

Remaining acceptance: owner visual review, physical-phone readability/touch/performance and live verified-board refresh against populated server data. No phone attached, Android export or device test. Spendable rewards and global flying-lap comparisons remain outside this implementation.
