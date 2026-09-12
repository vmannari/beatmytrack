# Slicks native test corpus — 2026-09-12

## Bridge-direction correction — 2026-09-12

G02/R03/R01: YLIKULKU's nearly square deck was assigned an east-west principal axis, although its side rails run north-south. This elevated the wrong route branch and made the underpass hit upper rails. Bulk conversion now derives travel direction from rail adjacency for parallel straight 39/40 bridge pieces. Mixed orientations and curved decks keep their existing inference pending a per-bridge representation; no physics architecture changed. Source-derived deck geometry is retained even when imperfect AI hints do not align with its upper branch.

Reconversion updates 33 native track files and their manifest hashes; the seven original reviewed fixtures remain unchanged. The exact affected list and before/after bridge metadata are in `evidence/bridge-axis-changes.json`. No bridges are removed. This fixes the shared straight-bridge inference; it is not an all-tracks drivability certification.

Actual commands: the bulk conversion and Python corpus commands below; `scripts/dev.ps1 TestCorpus`; `scripts/dev.ps1 TestTracks`; `scripts/dev.ps1 Snapshot -Track slicks_ylikulku_test -Overview`; original `test_convert.py`. Results: 194 conversions, zero failures; 793 corpus/runtime checks pass; 163 original track/lap/replay/ramp checks pass; 4 original converter tests pass. YLIKULKU completes three ordered AI laps in 27.446 / 26.627 / 26.623 seconds with zero collisions. Full collision sweeps in both directions verify upper/lower clearance and matching presentation heights, while the upper side rail remains solid. No failing invariant was weakened. Evidence: `evidence/bridge-axis-runtime.txt` and `evidence/ylikulku-bridge-overview.png`.

Changed implementation: `scripts/slicks/convert.py`, regenerated native track JSON/catalog and `game/tests/test_bulk_tracks.gd`. No phone test performed. Remaining acceptance: owner driving feel, mixed-direction bridges and individual bulk-track lap review. Restart the game to load corrected native content.

Owner request: convert every locally supplied track and provide author names for search. This extends G02/R03 native track content and R01 isolated offline conversion; it does not change handling or race rules.

## Delivered content

194 distinct tracks (187 additions, seven reviewed fixtures preserved byte-for-byte). The importer prefers newer sources for duplicate filenames, then the reviewed handoff for its four originals: 176 v2 sources and 18 v1 sources. Both the menu and playground discover tracks from `game/resources/builtin_tracks.json` rather than a fixed list. Runtime consumes native JSON only.

There are 71 case-insensitive author names. Existing source attribution is retained, including the raw source author. Five blank-author tracks receive deterministic fictional names: 8, ARABES and KANNAS use Nora Apex; KURPPA uses Finn Meadows; SPEED_UP uses Ada Coast. `creator_kind: fictional` distinguishes these assignments, and the selected-track byline labels them fictional. Creator search is case-insensitive.

Sources: owner-supplied handoff plus `C:/Users/ville/Downloads/194 Tracks for Slicks 1.29.zip` and `C:/Users/ville/Downloads/Additional tracks (175 tracks).zip`. The manifest records archive/source/native SHA256 hashes. Original files remain untouched and outside the export root. Inherited redistribution clearance remains unverified; these are local test fixtures.

## Conversion and quality limits

`scripts/slicks/bulk_convert.py` normalizes legacy tails, deduplicates sources, assigns metadata and emits native tracks/catalog. `corpus_config.json` holds extra object classifications, accepted flag variants and scale exceptions. The original strict converter path and seven reviewed golden fixtures remain unchanged. V1 normalization was compared against all 175 overlapping V2 sources: checkpoint/start/panic geometry agrees; computer-point geometry agrees, with three sources differing only in the additional V2 metadata byte.

Geometry comes from original SS objects, never screenshot tracing. Existing native surfaces, barriers, decks and rendering are used. Source starts, checkpoints and computer points remain in debug metadata. Spawn correction searches for the nearest road position with car clearance on both ground and deck layers; it does not move the finish/checkpoints. Correction distances are recorded per track.

Most layouts use 0.25 m/source pixel: a representative 36-pixel road is 9 m, approximately 5.68 current visible car widths (1.584 m). Actual widths vary. TYCO_GP has exceptionally narrow lanes and uses a data-driven 4x uniform scale; its nominal 36-pixel reference is 36 m, while its narrow actual lanes are much smaller. This preserves shape but makes its overall lap longer.

Eight tracks need AI-route review: AND2, ATOLLI, KARTING, SCORPION, SHORT, SL_LUIRU, TIE2 and TYCO_GP. Their source-order hints are retained when the clearance planner fails, with explicit manifest notes. This is a bulk loading/search corpus, not certification that every track completes laps or that every unusual bridge/flag has been individually verified. No new racing-line claim is made. Extra object-role and high-flag interpretations are documented in the configuration. FREEWAY remains the reviewed initial handling benchmark.

## Commands and verification

Run from repository root:

```powershell
.tools/review/Scripts/python.exe scripts/slicks/bulk_convert.py --archive 'C:/Users/ville/Downloads/194 Tracks for Slicks 1.29.zip' --archive 'C:/Users/ville/Downloads/Additional tracks (175 tracks).zip' --handoff build/slicks_handoff/slicks_codex_handoff
.tools/review/Scripts/python.exe scripts/slicks/test_bulk_convert.py build/slicks_handoff/slicks_codex_handoff 'C:/Users/ville/Downloads/194 Tracks for Slicks 1.29.zip' 'C:/Users/ville/Downloads/Additional tracks (175 tracks).zip'
.tools/review/Scripts/python.exe scripts/slicks/test_convert.py build/slicks_handoff/slicks_codex_handoff
.tools/review/Scripts/python.exe scripts/slicks/test_extra_convert.py 'C:/Users/ville/Downloads/Additional tracks (175 tracks).zip' build/slicks_handoff/slicks_codex_handoff/SLICKS.DAT
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestCorpus
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Snapshot -Screen tracks
```

Original converter tests: 4 passed; extra converter tests: 2 passed. Full Validate passed 620 checks during integration, including original lap/replay/bridge regressions. Corpus Python tests passed 3 tests, covering all 194 schemas/hashes and the 175 paired legacy sources. Final runtime results are recorded below. The runtime smoke test checks native loading, author attribution, collision-free spawns and 120 actual simulation ticks per track, plus real/fictional author search. It does not assert whole-lap completion for all 194.

Screenshot: `evidence/corpus-library.png` (194 built-ins plus one existing local saved track). No phone test or Android export was performed. Remaining acceptance: individual driving/AI/lap/bridge review of the bulk additions and device performance.

Changed files: offline bulk converter/config/tests and `convert.py`; native catalog/schema and 187 track JSON files; `BuiltinTracks`, app/playground discovery and runtime corpus test; native optional author schema. The separately developed track browser consumes the manifest author metadata.

Final results: converter emitted 194 tracks with zero failures; TestCorpus passed 781 checks; final Python corpus run passed 3 tests (24.159 s); TestApp passed 80 checks, including a five-lap created-track drive with zero contacts. Automatic spawn shifts: AND2 5.92927 m, BF-RIVER 7.77215 m and TYCO_GP 0.70711 m. Evidence: corpus-convert.txt, corpus-runtime.txt, corpus-runtime.json and corpus-library.png in docs/evidence. Initial spawn failures were corrected; no failing invariant was removed.
