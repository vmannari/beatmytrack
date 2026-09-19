# Tight hairpin island crossings — 2026-09-16

Requirements G01 / R03 / R07 / T02 / V05. Owner supplied another Silmukka screenshot, this time at a small grass island beside the bridge. This supersedes v7 acceptance for tight hairpins. The exact driving input is unavailable; tests reconstruct crossings of the two small constructed hairpins in the unchanged saved Silmukka fixture.

## Finding and correction

The generic detector required more than 8 m of progress gain and proof against the smoothed lap route. A small island can be driven straight across without satisfying that combination. Both new constructed-hairpin crossing assertions fail with the v7 detector and pass with the correction.

`NativeTrack.crosses_hairpin_infield` derives a crossing plane between the two legs from each constructed hairpin's position, heading, mirror, radius, width and straight length. It requires crossing through the interior of the grass island, with 1.55 m allowance from the analytical inside road edge for kerb plus standard car half-width. It rejects contact with an actual kerb and requires clearance from compiled ground/deck road cells by another car-half-width check (0.8 m). The latter prevents adjacent or crossing roads from being mistaken for an island. Coordinates come from the road pieces; there are no hand-placed checkpoints or Silmukka-specific runtime constants.

Crossing this region supplies direct shortcut evidence independently of the generic 8 m progress-gain gate. TrackSession applies the existing same-tick +5 s penalty and two-second notice; its latch prevents duplicate charges. The previous distance/progress detector remains for other kinds of cut. The road approach, actual kerb arcs and wide outside arcs are tested alongside the cut. Rules key advances to `standing-5-local-v8`; handling, road geometry, cameras and HUD layout are unchanged.

## Actual validation

All commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>` with pinned Godot 4.7.2.

| Action | Actual result |
| --- | --- |
| TestSilmukka | 194 checks, zero failures |
| TestRouteValidation | 55 checks, zero failures |
| TestTracks | 167 checks, zero failures, including driven native laps and replay comparisons |
| TestApp | 86 checks, zero failures |
| TestRecords | 53 checks, zero failures |
| TestPieces | 172 checks, zero failures |
| TestFreeEditor | 55 checks, zero failures |
| CaptureShortcutFeedback | 10 checks, zero failures |
| ReviewRouteValidation | 49 diagnostic trajectories; results retained, not asserted as legal driving |

The new cases cover both small Silmukka hairpins at 60/120/240 Hz, stopping on the grass before crossing, and a visible notice before reaching the opposite road. Road approaches followed by inner-kerb and outside arcs receive no penalty. The new geometry check also accepts all fourteen constructed pieces at their centre and both ±4 m road-edge paths (42 assertions). Earlier five-lap, duplicate-penalty, ordinary cut, outside-rejoin and notice tests remain.

The narrower 65–85 chord from the previous review is now penalized: the constructed-road test proves that it crosses the grass island despite saving less than the old 8 m gate. Its old expectation of zero penalties was based on the rejected generic tolerance; it was not a physical kerb-line proof. Actual kerb-line assertions remain unpenalized.

One provisional outside-arc test initially started directly off-road and failed the pre-existing route-progress heuristic. Adding the road approach made that full-session case pass; the approach is retained in the test, rather than removing the no-penalty assertion. A provisional 1.55 m clearance against coarse raster cells also missed the small islands; the final model applies that full allowance to analytical road geometry and car-half-width clearance to surrounding raster roads.

## Diagnostic correction and limits

The older saved-track sweep follows the independently smoothed lap route, not the actual constructed road. Some of those paths cross grass islands; they cannot all be labelled legal. In this run only 8 of the 21 centre/±4 m diagnostic paths finish without penalties. Those changed outcomes are preserved in the log rather than reported as passes or hidden. The authoritative new no-cut assertions use constructed road paths and real kerb/outside arcs. This does not establish that every diagnostic penalty is correct; complex overlapping geometry remains a human driving acceptance concern.

The saved Silmukka JSON matches the test fixture exactly and was not modified. The screenshot's exact input sequence was not replayed. No phone/device or mobile-performance test was performed. Full Validate was not rerun and the earlier engine-process crash is not claimed resolved. Existing HUD captures were regenerated; no visible UI changes were made. Unrelated workspace changes remain untouched; no combined Git commit was made.

Changed files: `game/track/native_track.gd`, `game/race/track_session.gd`, `game/race/race_rules.gd`, `game/tests/test_silmukka.gd`, this document and status/plan links. [Evidence logs and regenerated warning captures](evidence/tight-hairpin-crossings/), including the failing baseline and final tests. `git diff --check` on changed runtime files passed with existing CRLF normalization notices.
