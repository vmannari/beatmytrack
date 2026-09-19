# Superseded v3 validation record

The owner rejected this behavior on 2026-09-16 after driving it. Passing tests below were insufficient acceptance evidence. Current implementation: [ROUTE_PROGRESS_VALIDATION.md](ROUTE_PROGRESS_VALIDATION.md).

# Automatic route coverage - 2026-09-16

Requirements: G01 / R03 / R07 / T02. Owner requested review and correction of over-sensitive shortcut penalties on hairpins and kerbs.

## Review

Using the ordered route as the source of automatic validation is appropriate. Comparing each nearest-segment progress jump with that tick's physical travel is not reliable. Closely spaced hairpin legs, sharp vertices and intersections can change the nearest segment abruptly during legitimate driving. The previous asphalt-contact check only added 2 m of allowance; it did not exempt kerb driving. Fixed per-tick bonuses also allowed slow cuts, while accumulating only positive progress let forward/reverse movement manufacture lap distance. The previous 80% finish threshold could accept incomplete coverage.

## Replacement

`NativeTrack` caches ordered route witnesses at no more than 2 m spacing, preserving original vertices. They are rotated around the finish's projected route position because imported route origins need not coincide with the stripe. Each witness uses a local road-width radius measured from the surface grid (asphalt, native kerbs and dirt), plus 2 m for raised creator kerbs, car overlap and raster tolerance. Width measurement is bounded near intersections; an off-road route sample falls back to the track's representative width. This is a forgiving geometric course corridor, not an exact tyre-contact rule.

`TrackSession` consumes these witnesses in order using the complete swept movement segment. Multiple witnesses within a tick must be visited in chronological order. Validation is independent of the vehicle's nearest-route hint, curve-side classification, vertex count and per-tick jump thresholds. Camping and reversing cannot repeatedly credit the same section. No manually placed checkpoint rectangle controls lap validity; the old checkpoint counter is only derived debug presentation.

Early feedback requires the car to be more than 3 m beyond the next witness tolerance, skip at least 12 m (or twice that witness radius) of required route, and rejoin the interior of a later road section while travelling forward along it. The car must also have left the recently covered road corridor, so overlapping start/finish approaches do not masquerade as a skipped lap. Continuous evidence must last **0.4 seconds and at least 2 m of movement**. Then the existing HUD receives the shortcut warning and +5 seconds immediately. Returning to the required route, reversing, stopping or losing clear rejoin evidence clears the pending observation. One penalty is issued per invalid lap attempt.

A forward finish crossing after leaving the start neighbourhood closes an attempt. All witnesses must have been visited and the lap must not have been marked invalid. The finish remains a fallback for shortcuts too close to the stripe to confirm early; it never duplicates an early penalty. An invalid attempt does not increment completed laps; coverage and the flying-lap clock reset for recovery. The race retains the invalid attempt's elapsed time and penalty, and any shortcut excludes the run from local PBs. Normal races still require five valid laps. Finished race totals now retain the fractional crossing time rather than rounding up to the simulation tick; this keeps them consistent with lap sums and record validation. Scoring partition is `standing-5-local-v3`; earlier PB data is retained in its original partition.

## Files

- `game/track/native_track.gd`: cached witnesses, local tolerance, removal of obsolete shortcut heuristics.
- `game/race/track_session.gd`: ordered swept coverage, finish validation and recovery timing, early confirmation, exact fractional finish totals.
- `game/core/game.gd`: remove obsolete projection-progress initialization.
- `game/race/race_rules.gd`: new local scoring partition.
- `game/tests/test_route_validation.gd`: focused behavioral regressions.
- `game/tests/test_tracks.gd`: assert zero penalties on driven laps; replace obsolete manual-checkpoint acceptance with rejection of isolated checkpoint crossings.
- `scripts/dev.ps1`: `TestRouteValidation` entry point and inclusion in `Validate`.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document: current behavior and evidence.

## Actual verification

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot 4.7.2.

- `TestRouteValidation`: 32 checks, zero failures. Inner/outer kerb lines, mirrored hairpins, nonuniform route sampling, misleading branch hints, three movement step sizes, dirt, figure-eight crossings, omitted junction loops even on asphalt, slow/high-speed cuts, reverse farming, stationary/start behavior, five laps, finish freeze and recovery timing. Early-warning latency measured exactly 0.4 s at 60/120/240 Hz with a 24 m/s rejoin; transient evidence/recovery, no duplicate finish penalty and fractional finished totals also pass. An actual AI-driven 66 lap covers the adjacent imported start/finish regression.
- `TestFreeEditor`: 55 checks, zero failures; five driven crossing-route laps, zero contacts, replay checks.
- `TestPieces`: 164 checks, zero failures; five driven creator-road laps, zero contacts.
- `TestRecords`: 53 checks, zero failures.
- `TestTracks`: 167 checks, zero failures. FREEWAY, 1WAY, 66 and OFFROAD each complete three driven laps with zero shortcut penalties and exact JSON replays; existing bridge/collision checks pass.
- `TestCorpus`: 793 checks, zero failures, including three YLIKULKU laps with zero contacts.
- `TestApp`: 86 checks, zero failures; result feedback, saved PBs and reloaded PB presentation pass.
- `CheckScript -ScriptPath res://persistence/handling_recorder.gd`: standalone verbose parse passed.
- `Validate`: attempted twice. Both attempts imported and began script checks, then the Godot process exited with Windows access violation `-1073741819` while checking `handling_recorder.gd`, without a script diagnostic. The same file's standalone verbose check passed. **Full Validate did not pass.** Logs: `build/route-full-validation.log` and `build/route-full-validation-retry.log`.

Total: **1,350 passing checks** across the seven targeted suites. The initial `TestApp` run exposed five result/PB failures, fixed by preserving fractional finished totals. The early-feedback test iteration also caught a false penalty on 66 before its first turn; the recent-road continuity guard fixed it without changing the zero-penalty requirement. Saved evidence is in `docs/evidence/route-validation/`; working logs are in `build/*tests.log`. `git diff --check` passed for changed tracked files (only line-ending notices).

## Limits and remaining acceptance

No physical-phone test or APK export was performed; device attachment was not enumerated. No art, camera or UI layout was changed, so no new visual capture is claimed. The focused tests exercise geometric trajectories; existing driven suites exercise the actual simulation and replay. Owner driving of the reported tight hairpins is still required.

This remains local, unverified scoring. Extreme wide off-road detours can miss the allowed course corridor and invalidate an attempt even when slower. Very close overlapping roads and intentionally ambiguous creator routes cannot always express distinct obligations geometrically. Early warnings wait for a clear later-road rejoin; they are not guaranteed 0.4 s from the moment a car leaves the road. Very slow rejoins take longer to meet the 2 m confirmation requirement. Deliberate finish placement on a repeated route segment needs further authoring constraints. Full driven validation of every corpus track, phone performance and human acceptance are outstanding. No handling/physics or track-file schema change was made.
