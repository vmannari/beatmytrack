# Storm wet-asphalt tire rolling, 2026-10-09

The owner removes storm rain audio and requests tire rolling on wet asphalt
that follows speed. SND19 implements this correction to SND04/SND05, with
G01/R01/Q01/V06 presentation and canonical-state checks.

`StormWeather` now creates only its occasional thunder voice. Visual weather,
lightning and delayed thunder remain. The old rain WAV is retained as an unused
historical asset; no runtime code loads or plays it.

The existing road voice selects `wet_road.wav` in Storm. Four-wheel pavement
coverage controls its mix. Gain increases through the driving-speed range;
pitch stays bounded at 0.84–1.14. At rest, airborne, overturned, off asphalt and
during countdown, road contact is immediately silent. Pause suspends playback;
retry/rewind reset existing mixer state. Puddle spray uses actual water contact,
including retained tire water, instead of a biome-wide maximum. Normal grass,
sand and dry asphalt still select their established layers. No additional
playback voices, physics/rules changes, UI labels or runtime dependencies.

The new 5.9-second loop is offline sound design: filtered Nox CC0 car-interior
rolling plus original sustained spray hiss. It is not a dedicated wet-road field
recording. The builder, shipped notice and manifest retain provenance. The bank
now contains 47 clips/10,786,852 bytes; all 46 existing WAVs match historical
manifest hashes plus the subsequent three-impact onset audit. Looping voices
remain bounded at 22 per race, with one fewer weather voice.

Changed files: `game/track/storm_weather.gd`,
`game/vehicle/vehicle_audio.gd`, `scripts/build_vehicle_audio.py`,
`game/assets/audio/vehicles/{wet_road.wav,wet_road.wav.import,manifest.json,NOTICE.txt}`,
`game/tests/{test_vehicle_audio.gd,test_storm.gd,test_wet_road_audio.gd,test_wet_road_audio.gd.uid}`,
`scripts/review_wet_road_audio.py`, this document, `licenses/ASSETS.md`,
`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` and pinned 4.7.2.stable.official.ed1daf0bf.

| Actual command suffix / command | Actual outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py` | 47 clips; peak ceiling -1.514 dBFS. |
| `Import` | Exit 0 with local Windows access. Restricted initial run could not read the Windows certificate store and was stopped; approved retry succeeds. |
| `TestScript -ScriptPath res://tests/test_wet_road_audio.gd` | 33 checks, 0 failures. |
| `TestScript -ScriptPath res://tests/test_wet_road_audio.gd -Graphical -TestArgument @('--capture')` via PowerShell `-Command` | 40 checks, 0 failures; six actual 48 kHz native PCM captures. Initial `-File` argument spelling failed before engine execution. |
| `TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | 1,446 checks, 0 failures, including exact 960-tick canonical equivalence and bank hashes. |
| `TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | 67 checks, 0 failures; exit 0 after delayed shutdown. An attempted narrowly scoped cleanup found no matching owned process and stopped nothing. |
| `TestScript -ScriptPath res://tests/test_continuous_desert_audio.gd` | 28 checks, 0 failures; exit 0. |
| `TestScript -ScriptPath res://tests/test_storm.gd` | 94 checks, 2 pre-existing visual spray failures, identical messages to `docs/evidence/verification-speed-2026-10-09/storm-validation-failure.log`. Weather/pause/thunder assertions pass. Initial adaptation queried paused state on an inactive thunder stream; corrected to test unchanged weather clock/no thunder start/count, with the separate active-thunder pause check retained. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/wet-road-audio-2026-10-09/continuity.json` | 40 looped assets including repeated wrap boundaries, 0 failures. |
| `python scripts/review_wet_road_audio.py` | Six native captures, all 46 earlier masters unchanged, 0 failures. |

Native isolated rolling RMS at 14.4/57.6/144 km/h is -37.42/-32.58/-27.44 dBFS;
stopped/airborne/paused PCM is exactly zero. Audio measurements verify behavior
and continuity, not owner approval of realism or the full game mix. Listening
samples: [review.html](evidence/wet-road-audio-2026-10-09/review.html).
Reports and the scoped review patch remain in the same evidence directory.
The text patch passes `git -c core.autocrlf=false apply --reverse --check
--ignore-space-change docs/evidence/wet-road-audio-2026-10-09/task-review.patch`.
Default Git whitespace handling initially rejected CRLF working files; no
runtime files were changed by either read-only patch check. The new WAV is
stored separately and pinned by `checkpoint-files.json` and the bank manifest.
The before-source files are reconstructed by reversing this task's edits because
the initial backup command failed; PCM preservation is checked independently
against the earlier saved manifest and onset audit. Existing workspace edits
are preserved; the review patch stages no unrelated work.

No phone attachment check or physical-device listening/performance test,
Android export/install, full Validate, physics merge or deployment was performed.
Remaining acceptance: owner listening to texture/balance in normal storm driving
and on the target device. The two existing visual spray failures remain open.
