# Storm wet-asphalt tire rolling, 2026-10-09

Current state: the owner rejected wet rolling and moved it to the wishlist.
Storm asphalt rolling is disabled; the quiet distant rain remains. The
implementation history below is superseded by the final deferral section.

The follow-up correction below raises wet rolling and adds quiet recorded rain
at the owner's request. It supersedes this first revision's rain removal and mix.
The latest distant-rain correction at the end replaces the close surface-drop
recording with a softer rural rain field suited to the overhead view.

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

## Stronger wet rolling and quiet recorded rain

The owner cannot hear wet tires well enough and now explicitly requests a
suitable quiet background rain recording. SND21 (wet-tire presence) and SND22
(recorded rain), with SND04/SND05/G01/R01/Q01/V06, implement this follow-up.
Wet road gain is three times the previous value (+9.542 dB), with the same
speed response, wheel contacts, bounded pitch, stop/airborne/countdown/retry
guards and 22 mixer voices. None of the 47 vehicle WAVs change.

One race-owned 19-second mono PCM rain loop replaces the earlier synthetic
rain reference. The source is [Rain on concrete by Joseph SARDIN,
BigSoundBank sound 1289](https://bigsoundbank.com/rain-on-concrete-s1289.html),
whose page confirms an outdoor recording and CC0 licence. The shipping
derivative extracts seconds 20–40, softens rumble/high frequencies and sharp
drop transients, and crossfades a cyclic one-second seam. The first candidate
had disproportionately strong isolated drops and was remastered before use.
Source SHA256 `e4876e37514c40728637c6caaed6068209c00f77b80557752f237bb02c7bdbef`;
derivative SHA256 `8e6eef9c6c9651caaeec3f19a02afaf3fe77a02c050daffecfad4ec7b604d5de`,
1,675,844 bytes, RMS -21.938 dBFS. Rebuilding offline preserves identical bytes.
Rain plays at 0.13 gain, about -39.7 dBFS nominal, on the existing Vehicle bus
so vehicle volume/master mute apply. It fades in/out over 0.75 seconds,
suspends with race pause/background focus and fades out on race finish.
Retry/theme replacement/exit stop the old race-owned voice. Occasional delayed
thunder remains. No new UI, physics/rules, source services or runtime dependencies.

Follow-up changed files: `game/vehicle/vehicle_audio.gd`,
`game/track/storm_weather.gd`, the storm advance call in `game/core/game.gd`,
`game/tests/test_wet_road_audio.gd`,
`game/tests/capture_storm_audio_balance.gd` and its UID,
`scripts/build_storm_rain.py`, `scripts/review_storm_audio_balance.py`,
`game/assets/audio/ambience/{storm_rain_recorded.wav,storm_rain_recorded.wav.import,storm_rain_manifest.json,NOTICE.txt}`,
this page, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and `licenses/ASSETS.md`.

Actual commands use the pinned `scripts/dev.ps1` entry point as above:

- `python scripts/build_storm_rain.py --fetch`: source/licence fetched with
  approved network access after the restricted socket attempt failed. No login,
  purchase or account. `python scripts/build_storm_rain.py`: exact offline rebuild.
- `Import`: exit 0.
- `TestScript -ScriptPath res://tests/test_wet_road_audio.gd`: final 38 checks,
  zero failures, including separate focus/pause/finish guards.
- `TestScript -ScriptPath res://tests/test_vehicle_audio.gd`: 1,446 checks,
  zero failures, including exact 960-tick canonical equivalence.
- `TestScript -ScriptPath res://tests/test_storm.gd`: 94 checks, the same two
  previously recorded visual spray failures; weather/thunder checks pass.
- `TestScript -ScriptPath res://tests/capture_storm_audio_balance.gd -Graphical`:
  final 30 checks, zero failures; seven same-clock mixer/engine/wet/rain sets,
  including a real rain-loop wrap. Final capture exits cleanly.
- `python scripts/review_storm_audio_balance.py`: zero failures; measured wet
  increase 9.5299 dB. At 57.6/115.2 km/h wet/engine relative levels are -3.21/
  +1.59 dB for compact and +1.45 dB for Formula at 115.2 km/h. Quiet rain is
  16.66/22.07/20.79 dB below wet rolling respectively. Stationary wet and all
  paused PCM are exactly zero; rain remains audible at rest. No clipped output
  or dropout windows in source repeated seams or 21s native rain recording.
  All 47 vehicle WAV hashes match the actual before-task snapshot.
- `TestApp`: 99 checks, zero failures; race creation/return/record lifecycle.

Native mix evidence, actual capture receipts, continuity/mix measurements and
the task-only review patch are in `docs/evidence/storm-audio-balance-2026-10-09/`.
The initial shorter unpaired gain comparison and a later capture interrupted by
desktop focus changes are retained. The final fixture models foreground play
explicitly; pause/background behavior is tested separately. No failures were
removed from the production contracts. Listening review:
[wet tires, engine and quiet rain](evidence/storm-audio-balance-2026-10-09/review.html).

The initial old-level fixture briefly restored full wet gain between separate
volume writes, allowing the audio thread to read that intermediate level. The
final comparison uses a private one-third-level PCM copy as the mathematically
equivalent previous wet level; both versions use the same held speed/engine,
quiet rain and loop cursor. Shipping assets and the reviewed gain invariant
remain unchanged. Initial measurement failures and recordings are retained.

No physical-device listening/performance test, phone attachment check,
Android export/install, full Validate, physics merge, backend or deployment.
Owner hearing/texture approval in the normal game mix, music balance and
target-device listening remain; native PCM measurements do not prove these.

Follow-up checkpoint: `docs/evidence/storm-audio-balance-2026-10-09/task-review.patch`
and `checkpoint-files.json`. The text patch includes only this task's changes;
the new WAV is retained separately with its pinned hash. Read-only reverse
verification uses `git -c core.autocrlf=false apply --reverse --check
--ignore-space-change --whitespace=error-all` against that patch. Current
unrelated workspace changes are preserved and unstaged.

## Distant rain for the overhead view

The owner rejects close individual drops because the game is viewed from far
above. SND23 corrects the rain perspective while retaining SND21/SND22 and
SND05/G01/R01/Q01/V06. The active asset now uses [Rain light 1 (rural) by
jmbphilmes, Freesound 200271](https://freesound.org/people/jmbphilmes/sounds/200271/).
The source page describes rural background rain without surrounding sounds
and confirms CC0. The public HQ MP3 preview is fetched without an account,
then decoded offline by the pinned Godot engine; the preview quality is explicit
in the manifest. This is a designed distant perspective from a ground recording,
not a claim that the source was recorded above the track.

Four distinct 25-second regions blend local drops into a diffuse field. A
100 Hz–2.2 kHz filter softens close bright detail, restrained transient limiting
smooths the remaining peaks, and a one-second cyclic crossfade produces a
24-second mono PCM loop. RMS is -25.193 dBFS, 3.255 dB below the rejected asset;
crest factor falls from 14.125 to 11.016 dB and energy above 3 kHz from 43.52%
to 0.0216%. These measurements substantiate softer/quieter processing and do
not establish subjective distance/realism approval. Wet tire/engine masters,
mix gains and runtime pause/focus/finish behavior are unchanged by this task.

Asset 2,116,844 bytes, SHA256
`45333e5c5b6b23e75ac063a54d763e8cb49b57af9cf6e1b5885426daad75b7a6`;
encoded source SHA256
`9150f775fea3c4aa020edff9174fb0d1a1d4c5cfe464a0ce6f3dd414065005be`.
Manifest also pins decoded float bytes. Previous close-rain asset/source and
historical recordings remain outside exports; shipping notice is updated.

Changed files: `scripts/build_storm_rain.py`,
`scripts/review_distant_storm_rain.py`, `scripts/review_storm_audio_balance.py`,
`game/tests/decode_storm_rain_source.gd` and UID,
`game/tests/capture_storm_audio_balance.gd`,
`game/assets/audio/ambience/{storm_rain_recorded.wav,storm_rain_recorded.wav.import,storm_rain_manifest.json,NOTICE.txt}`,
this page, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.
Capture/review tools now accept a separate evidence directory so previous
listening evidence is preserved. No camera, UI, simulation or runtime code changes.

Actual pinned commands and outcomes:

- Public source/licence fetch: approved Python HTTPS fetch; licence HTML and
  exact URL/hash retained in `build/storm_rain_sources/`. Reproducible fetch:
  `python scripts/build_storm_rain.py --fetch` (decode/build then follow separately).
- `TestScript -ScriptPath res://tests/decode_storm_rain_source.gd`:
  3,975,329 mono float frames at 44.1 kHz, exit 0.
- `python scripts/build_storm_rain.py`: initial and repeat offline builds have
  identical derivative SHA256. `Import`: exit 0.
- `TestScript -ScriptPath res://tests/test_wet_road_audio.gd`: 38 checks,
  zero failures, exit 0; 55 ObjectDB shutdown warnings retained in the log.
- `python scripts/review_distant_storm_rain.py`: zero failures; all 47 vehicle
  WAVs unchanged, quieter/softer comparison and repeated source seam checks.
- `TestScript -ScriptPath res://tests/capture_storm_audio_balance.gd -Graphical`
  with `--evidence-dir=res://../docs/evidence/distant-storm-rain-2026-10-09`:
  final 30 checks, zero failures, clean exit, actual rain wrap captured.
- `python scripts/review_storm_audio_balance.py --evidence-dir
  docs/evidence/distant-storm-rain-2026-10-09`: zero failures. Native rain RMS
  -42.92 dBFS, 19.58–24.56 dB below rolling in the driving scenarios; no clipping,
  no dropout windows through the 26-second recording, all paused layers zero.
  Existing wet gain comparison remains +9.535 dB.

Evidence and task-only patch:
`docs/evidence/distant-storm-rain-2026-10-09/`. Initial native capture had no
dropouts but its fixed 21 seconds did not cross the replacement's longer
24-second loop; the existing wrap assertion failed. The capture now records
the actual loop duration plus two seconds, retaining the wrap requirement.
The failed receipt is preserved. Quiet before/after listening:
[distant rain comparison](evidence/distant-storm-rain-2026-10-09/distance-review.html).
Snapshot hashes confirm all 47 vehicle WAVs plus `StormWeather` and `game.gd`
unchanged. `vehicle_audio.gd` received concurrent impact-route diagnostics;
this rain task leaves that file untouched and excludes it from its patch.
The scoped text patch and binary hash receipt are retained in the evidence
directory; the before files for the two capture/review helpers are reconstructed
by reversing only this task's edits. Earlier evidence is preserved.

No phone attachment check, physical-device listening/performance test,
Android export/install, full Validate, backend or deployment. No visual UI change,
so audio captures replace screenshot evidence. Owner distant-perspective/mix
approval and device listening remain; the two earlier storm visual-test
failures remain outside this audio-only change.

## Wet tire rolling deferred at the owner's request

The owner rejects the wet tire sound and explicitly requests removing it for
now and adding it to the wishlist. SND24 supersedes the wet-rolling part of
SND19/SND21; SND22/SND23 distant rain remains. [Wishlist entry](WISHLIST.md)
records better realistic speed-dependent wet asphalt audio as deferred, with
audition in the full engine mix and overhead perspective before reintroduction.

`VehicleAudio.present` no longer loads/selects `wet_road.wav`. Its existing road
voice is immediately silent on Storm, including an incoming dry-road tail;
there is no dry-rolling replacement there. Ordinary dry road, slip/collision,
off-track feedback and actual puddle contact keep their established behavior.
The rejected WAV/source/builder and historical evidence are retained for this
temporary removal. All 47 vehicle WAVs and the quiet distant rain WAV are
byte-identical; no camera, physics/rules, UI or backend change.

Changed files: `game/vehicle/vehicle_audio.gd`,
`game/tests/test_vehicle_audio.gd`, `game/tests/test_wet_road_audio.gd`,
`docs/WISHLIST.md`, this page, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.
Existing assertions follow the owner's changed contract: storm rolling must be
silent without loading the wet derivative, while ordinary dry rolling and rain
lifecycle checks remain. This is an explicit requirement change, not a weakened
guard to conceal a failure.

Actual pinned `scripts/dev.ps1 TestScript` runs:

- `-ScriptPath res://tests/test_wet_road_audio.gd`: 39 checks, zero failures.
- `-ScriptPath res://tests/test_vehicle_audio.gd`: 1,446 checks, zero failures,
  including exact 960-tick canonical equivalence and bank hashes.
- `-ScriptPath res://tests/test_wet_road_audio.gd -Graphical` with `--capture`:
  52 checks, zero failures; all six native road-bus PCM recordings have peak
  exactly zero (slow/medium/fast/stopped/airborne/paused). Independent Python
  PCM review confirms silence; rain/weather source hash remains identical.

Task source snapshots, test logs and review patch:
`docs/evidence/wet-tires-deferred-2026-10-09/`. No phone attachment check,
physical-device listening, Android export/install, full Validate, backend or
deployment. No visible UI change. Owner confirmation in normal play remains;
the two earlier storm visual-test failures are outside this change.
