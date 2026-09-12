# Local personal-best storage

2026-09-12, R04 (separate standing-race/flying-lap records) and R07 foundations (recoverable local save). This store records local, unverified results; it is not an official leaderboard, anti-cheat check or economic save.

`game/persistence/local_records.gd` retains its `key_for`, `best_for`, `record`, `load_records`, `save_records` and `settings` APIs. Its optional constructor path and writable `path` support isolated tests. `best_for` returns seconds for existing menus. Stored schema 2 uses integer `race_ms` and `flying_ms`; JSON's parsed numeric values are normalized to integers before use. A valid schema 1 file with `race`/`flying` seconds migrates on load and upgrades at the next successful commit. Rounding uses the nearest millisecond.

Records are partitioned by native content hash, physics version, sorted handling snapshot and `standing-3-local-v1`. The first standing lap never contributes to the flying PB. Whole-race and flying records improve independently. Calls must supply exactly three finite positive lap times and an agreeing race total (within 2 ms); the app remains responsible for accepting only eligible completed live races.

Loads validate the complete schema, SHA-256-shaped keys, numeric integer millisecond values, record fields and settings. The only preferences are Boolean `left_handed` and numeric `touch_scale` from 1.0 to 1.4. Unknown fields, malformed records or unsupported versions invalidate the document and trigger backup recovery. Read files are bounded to 4 MiB, and times to positive signed 32-bit milliseconds. These are local format bounds; there is no race-attempt count limit.

Saves write and flush a temporary file, validate the read-back, preserve the previous good primary as a backup, and rename the temporary into place. A corrupt primary cannot replace a known-good backup. Reads use committed primary then valid backup; uncommitted temporaries never count as saved PBs. Any failed write restores in-memory records/settings to the last successfully loaded or committed state, so a failed result cannot appear as a saved PB. The app displays storage failure through its existing error notice. Hardware-level durability and Android force-stop behavior remain unverified.

Changed files: `game/persistence/local_records.gd`, `game/tests/test_records.gd`, this document and retained evidence. The app integration test was separately adapted to the integer-ms fields. No canonical vehicle/race step changed.

Actual command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRecords
```

Final result: **48 checks, zero failures**, exit 0, pinned Godot `4.7.2.stable.official.ed1daf0bf`. Retained output: [records-tests.txt](evidence/records-tests.txt). Tests cover save/load/settings, integer JSON values, content and handling partitioning, first-lap exclusion, bad lap inputs, corrupt/missing-primary recovery, preservation of a good backup, schema migration, failed migration rollback and simulated unwritable paths. The unwritable fixture uses a regular file where a directory is required; it does not modify host permissions or claim a physical full-disk test.

Development failures were fixed before this final run: parsed JSON schemas are floats, so integer-array membership was replaced by explicit finite numeric comparison; a test loop now explicitly assigns untyped arrays to `Array[float]`. Neither failure required relaxing a storage invariant.

Remaining acceptance: actual Android force-stop/relaunch and low-storage behavior, human retry/results behavior and cross-device replay verification. No phone test was performed for this work.
