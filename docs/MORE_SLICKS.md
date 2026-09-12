# Additional Slicks circuits — 2026-09-12

The owner approved current handling/collisions and explicitly requested more Slicks conversions, proper menus and a phone-friendly creator. This document covers the **three additional circuits** in that checkpoint. Requirements: **G02/R03** native circuit and ordered lap data, **R01** offline native runtime boundary, and **V01/V02** themed presentation support. No simulation, collision, car scale or gameplay camera values changed for these conversions.

| Native identity | Menu title / theme | Layout | Three AI lap times (s) | Contacts |
|---|---|---|---|---:|
| `slicks_arto4_test` | Pine Loop / `pine` | Broad twin asphalt loops around planted islands | 18.725, 16.763, 16.752 | 0 |
| `slicks_hiekka_test` | Dune Run / `desert` | Flowing bends around a pond, with a loose dirt/sand section | 25.261, 24.140, 24.158 | 0 |
| `slicks_ovaali3_test` | Coast Oval / `coast` | Fast waterside oval, long straights and broad bends | 16.475, 15.432, 15.456 | 0 |

All three are fully parsed v2 maps with reviewed block roles, no unsupported flags, no native bridge, and **no per-map geometry corrections**. They use the existing 0.25 m/source-pixel conversion, 80 × 50 m canvas and 9 m representative road. Each preserves stored start, original checkpoint order, computer-point debug data and block count. Source start/finish markings provide the native finish line. The converter's existing conservative routing and forgiving surface interpretation still apply; these are development adaptations, not a claim of exact original-game physics.

The stored `title`, `description` and `theme` are presentation metadata. `track_metadata` in the converter config adds these only to the new maps. The original FREEWAY, 1WAY, 66 and OFFROAD native files and their golden hashes remain unchanged. The menu and editor use the same allowlisted pine/coast/desert theme names; materials do not redefine the native road or blocking surfaces.

## Source and provenance

The initial handoff archive contains only the four existing fixtures. Further v2 source maps were found in the owner's existing local file `C:/Users/ville/Downloads/Additional tracks (175 tracks).zip`. The nearby `194 Tracks for Slicks 1.29.zip` contains older v1 files and was not used. No new archive or asset was downloaded.

Only selected source files were copied into ignored `build/more_slicks_source/original_tracks/`; matching `SLICKS.DAT` was copied from the existing extracted handoff. All original ZIPs, original `.SS` files and blueprint package remain untouched. Six candidates were rendered for inspection, with ARTO4, HIEKKA and OVAALI3 selected and their reference renders visually inspected. No screenshot tracing or reference image is used at runtime.

`scripts/slicks/extra_golden.json` pins the source ZIP SHA-256 (`5f9360866ff156ef5f79801f5da4b23c982d0dc1a25adffa7c6d46ea72671082`), DAT hash, three individual source hashes and three native output hashes. Each runtime JSON also retains source filename/hash and the explicit **redistribution clearance unverified** notice. These are owner-local development references; commercial redistribution or production clearance is not established.

## Files

- `scripts/slicks/convert.py` and `config.json`: optional map title/description/theme metadata, preserving old outputs.
- `scripts/slicks/extra_golden.json` and `test_extra_convert.py`: pinned archive/resource/source/native hashes, schema and source-contract validation.
- `game/resources/tracks/slicks_arto4_test.json`, `slicks_hiekka_test.json`, `slicks_ovaali3_test.json`: new native circuits.
- `game/tests/test_extra_tracks.gd`: full driven three-lap runs, collision clearance, exactly three-lap freeze and JSON replay.
- `docs/evidence/more-slicks-converter-tests.txt` and `more-slicks-track-tests.txt`: actual successful converter and runtime test output.

## Actual commands and outcomes

Commands ran from the project root in PowerShell without loading its profile, using the existing ignored review Python environment. No dependencies were installed. Python, Pillow and jsonschema are development tools only.

```powershell
.tools/review/Scripts/python.exe scripts/slicks/convert.py build/more_slicks_source --track ARTO4 --track HIEKKA --track OVAALI3
.tools/review/Scripts/python.exe scripts/slicks/test_convert.py build/slicks_handoff/slicks_codex_handoff
.tools/review/Scripts/python.exe scripts/slicks/test_extra_convert.py 'C:/Users/ville/Downloads/Additional tracks (175 tracks).zip' build/slicks_handoff/slicks_codex_handoff/SLICKS.DAT
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_extra_tracks.gd
```

Actual outcomes:

- Converter generated 131, 189 and 147 route points respectively; all three native JSONs pass `docs/native_track.schema.json`.
- Original converter suite: **4 tests passed**, including exact original fixture golden bytes and unknown-role rejection.
- New converter suite: **2 tests passed**, covering source ZIP/DAT pins and all three source/native/schema contracts. A first PowerShell `2>&1 | Tee-Object` attempt reported shell exit 1 despite unittest printing `OK`, because PowerShell wrapped unittest's stderr progress as native errors. The captured rerun used Python subprocess merged output and correctly exited 0; the successful output is retained.
- Pinned engine **4.7.2.stable.official.ed1daf0bf**, **handling-0.13**, **arcade-planar-0.12**: **27 runtime checks passed, zero failures**. Every map completed exactly three laps with zero blocking contacts. Complete quantized-input recordings survived JSON roundtrip and replayed to exactly identical state and lap times in batches of eight ticks. Spawns are clear and finished counters/timers freeze.

These laps measure the existing conservative diagnostic driver on Windows. Human race pace, fairness/shortcut validation and phone performance are separate acceptance checks; no cross-device determinism claim is made. Presentation screenshots and full application validation belong to the integrated menu/editor checkpoint.

## Remaining acceptance

Drive each map manually in the menu build; inspect road/curb/surface legibility in all three themes; confirm generous corners and the sand transition remain enjoyable. Check phone layout, simultaneous touch, bright-light readability and sustained frame pacing on the target device. Physical-phone attachment was not enumerated for this conversion task; no device test or APK export was performed here. Production distribution still requires source-layout clearance.
