# Storm wet-asphalt tire rolling, 2026-10-09

Current state: the owner rejected wet rolling and moved it to the wishlist.
Storm asphalt rolling is disabled; the owner-supplied rain now plays as a
20-second loop at 0.28 gain with strong recorded delayed thunder. The
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

## Distant rain presence correction

The owner cannot hear rain after wet tire removal. SND25 raises the existing
soft distant rain gain from 0.13 to 0.55 (+12.529 dB configured). The recording,
filtering/distant texture, wet-tire deferral, wishlist, engine gains and existing
fade/pause/background/finish lifecycle remain. No new asset or bus in the game;
extra reference buses exist only in the diagnostic capture.

Changed files: `game/track/storm_weather.gd` (one level constant),
`game/assets/audio/ambience/NOTICE.txt` (current playback level),
`game/tests/capture_rain_presence.gd` and UID,
`scripts/review_rain_presence.py`, this page, `DEVELOPMENT_STATUS.md`,
`docs/PHASE_0_PLAN.md`. The rain WAV, deferred wet mixer and wishlist hashes
match the actual before-task snapshot.

Actual pinned `scripts/dev.ps1` commands:

- `TestScript -ScriptPath res://tests/test_wet_road_audio.gd`: 39 checks,
  zero failures, including wet silence and rain pause/focus/finish guards.
- `TestScript -ScriptPath res://tests/capture_rain_presence.gd -Graphical`:
  final 26 checks, zero failures, clean exit. The actual Game scene/presentation
  runs at held 86.4 km/h with default race music/engine settings; canonical
  stepping is disabled, so this is a foreground presentation fixture, not
  a completed race or actual player-driving acceptance.
- `python scripts/review_rain_presence.py`: zero failures; measured increase
  12.524 dB, rain -30.245 dBFS versus engine -20.147 dBFS (10.098 dB below).
  Default music is present, output stays below the limiter ceiling, all paused
  PCM is zero, and Vehicle mute leaves only music (0.022 dB RMS difference
  after accounting for the actual 0.7 Music bus gain).

Initial capture used a Node-only timing method on SceneTree and then encountered
desktop auto-pause plus an incorrect `playing` assertion on paused playback.
The final fixture explicitly drives foreground `Game._process` with the proper
paused-stream check. Initial mute review compared pre-volume music against
final output; the corrected comparison uses the recorded Music bus gain without
relaxing the mute invariant. Those receipts are retained. One automatic approval
review timed out before execution; its permitted retry succeeded.

Evidence/source checkpoint and [default engine/music listening comparison](evidence/rain-presence-2026-10-09/review.html):
`docs/evidence/rain-presence-2026-10-09/`. No phone attachment check,
physical-device listening, APK export/install, full Validate, physics change,
backend or deployment. Owner audible-background/distant-texture approval and
device/music listening remain; the two earlier visual spray failures remain
outside this gain-only change.

## Owner-supplied rain loop, 2026-10-10

The owner provides `dragon-studio-copyright-free-rain-sounds-331497.mp3` and
requests a shorter loop. SND26 replaces the rain recording while preserving
SND24 wet-tire deferral and SND25 playback/lifecycle. Only the 20–41-second
section of the 467.827-second recording is decoded. A one-second cosine cyclic
crossfade gives a 20-second mono 44.1 kHz/16-bit PCM loop. DC removal, gentle
rare-peak control and level matching preserve the supplied texture without EQ
or added layers. The first peak-capped candidate was too quiet (-41.37 dBFS)
and is retained; the final loop matches the prior -25.193 dBFS asset RMS.

Final WAV 1,764,044 bytes/SHA256
`3bed8b7e81b1a278c55dc1eb39a8b8dd4b890fa252e6bc08372513f730a15dcc`.
Original MP3 SHA256
`1142dde3666dad8d65e163eaca9292edcb7710afa4b81a9b7cbb93dab1a10e0c`;
decoded excerpt hash is in the shipping manifest. Original Downloads file is
unchanged. Source copy/decoded excerpt and previous rain assets remain in
export-excluded build/evidence storage. Attribution is recorded from the
filename as Dragon Studio; no CC0/other licence is inferred from the filename,
and no licence document was supplied. Local use/edit is explicitly requested.

Changed files: `scripts/build_storm_rain.py`,
`scripts/review_owner_rain.py`, `scripts/review_rain_presence.py`,
`game/tests/decode_storm_rain_source.gd`, `game/tests/capture_rain_presence.gd`,
`game/assets/audio/ambience/{storm_rain_recorded.wav,storm_rain_recorded.wav.import,storm_rain_manifest.json,NOTICE.txt}`,
this page, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.
No runtime code/gain, camera, physics, UI, backend or dependency changes.

Actual pinned `scripts/dev.ps1` commands and outcomes:

- Source copied from the owner's explicitly named Downloads MP3 into
  `build/storm_rain_sources/owner-rain-331497.mp3`; hash pinned.
- `TestScript -ScriptPath res://tests/decode_storm_rain_source.gd` with
  `--source-base=owner-rain-331497 --start-seconds=20 --seconds=21`:
  926,100 mono float frames at 44.1 kHz, exit 0. Full recording not decoded.
- `python scripts/build_storm_rain.py`: final and repeat offline builds have
  identical SHA256. `Import`: exit 0. Initial same-path delete/add patch was
  rejected before file edits; ordinary update patch succeeds.
- `TestScript -ScriptPath res://tests/test_wet_road_audio.gd`: 39 checks,
  zero failures.
- `TestScript -ScriptPath res://tests/capture_rain_presence.gd -Graphical` with
  `--evidence-dir=res://../docs/evidence/owner-rain-2026-10-10 --capture-loop`:
  33 checks, zero failures, actual owner-rain playback wrap captured.
- `python scripts/review_rain_presence.py --evidence-dir
  docs/evidence/owner-rain-2026-10-10`: zero failures; default engine/music mix,
  rain 10.061 dB below engine, paused PCM zero, mute leaves only music.
- `python scripts/review_owner_rain.py`: zero failures; 20-second asset,
  repeated seams and actual native loop have zero dropout windows; one native
  wrap. All 47 vehicle WAVs, playback gains, wet mixer and wishlist hashes match
  the actual before-task snapshot.

Evidence/scoped patch: `docs/evidence/owner-rain-2026-10-10/`.
[Repeatable loop preview](evidence/owner-rain-2026-10-10/loop-review.html).
No phone attachment check, physical-device listening, APK export/install,
full Validate, backend or deployment. Owner listening and device acceptance
remain; previous storm visual spray failures are outside this audio asset change.


## Slightly quieter rain, 2026-10-10

SND27: owner requests slightly quieter rain. `StormWeather.RAIN_LEVEL` changes
from0.55 to0.45:18.18% lower linear gain (-1.743dB). The supplied20-second WAV
remains byte-identical, and wet tires remain deferred. Existing fades, vehicle
volume/mute and pause/focus/finish behavior remain.

Changed files: `game/track/storm_weather.gd`, ambience `NOTICE.txt`, this page,
`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. Actual command:
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript
-ScriptPath res://tests/test_wet_road_audio.gd`:39 checks, zero failures, exit0;
117 ObjectDB shutdown warnings retained. Source hash check confirms unchanged
WAV. Updated level preview and scoped source patch are in
`docs/evidence/rain-quieter-2026-10-10/`. No phone attachment check/device
listening/native acoustic capture/Android export-install/full Validate/backend
or deployment. Owner final volume acceptance remains.

## Another rain reduction and recorded thunder, 2026-10-10

SND28 repeats the previous18.18% reduction: rain gain0.45 to0.36818182,
-1.743dB. SND29 replaces the quiet synthetic thunder placeholder with
[Thunder3 by Joseph SARDIN and Axeline T.](https://bigsoundbank.com/thunder-3-s3114.html),
whose source page confirms CC0 and one outdoor thunderclap without rain.
The7.5s mono44.1kHz PCM excerpt starts at the first sustained energy, is
softened to45Hz–3.2kHz, and has a15ms attack/1s release. Its0.65 gain rises
clearly above the rain in captured playback. The existing1.2–2.8s delay after
lightning,9–16s strike spacing, one voice and pitch variation remain. Thunder
now routes through Vehicle volume/mute with rain and obeys pause/background.
The owner's20s rain WAV, all47 vehicle WAVs, wet mixer and wishlist are unchanged.

Source SHA256 `448d45edf4022a0ac979a076e997321abcef3807cc8f41dcae2be2e317360255`;
derivative `7ad33f2ef4b9ad3e38faac86c42feb683a6203abe058592cac8e18c52e0c3093`,
661,544 bytes. Licence HTML/source/pinned receipt retained under
`build/storm_thunder_sources/`; old synthetic clip retained as historical
evidence. Current rebuild is `scripts/build_storm_thunder.py`; the earlier
`generate_storm_audio.py` is historical synthesis tooling, not the current
recorded-thunder build path.

Changed files: `game/track/storm_weather.gd`,
`game/assets/audio/{storm_thunder.wav,storm_thunder.wav.import,storm_thunder_manifest.json}`,
ambience `NOTICE.txt`, `game/tests/test_wet_road_audio.gd`,
`game/tests/capture_thunder_audio.gd` and UID,
`scripts/build_storm_thunder.py`, `scripts/review_thunder_audio.py`, this page,
`licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands (engine uses pinned `scripts/dev.ps1`):

- `python scripts/build_storm_thunder.py --fetch`: verified CC0 page/source
  fetched with approved network access; no account/purchase. Repeat offline
  `python scripts/build_storm_thunder.py` produces identical derivative bytes.
- `Import`: exit0.
- `TestScript -ScriptPath res://tests/test_wet_road_audio.gd`:40 checks,
  zero failures, including thunder Vehicle volume and wet deferral.
- `TestScript -ScriptPath res://tests/capture_thunder_audio.gd -Graphical`:
  19 checks, zero failures; actual race presentation/default music, one
  lightning/delayed thunder event, pause freezes pending cue, muted cue still
  plays only into its pre-mute reference.
- `python scripts/review_thunder_audio.py`: zero failures; rain -34.024dBFS,
  thunder transient -17.347dBFS versus engine -20.122dBFS; all paused PCM zero;
  Vehicle mute leaves only music within0.003dB RMS. Mix peak0.595 has headroom.
- `TestScript -ScriptPath res://tests/test_storm.gd`:94 checks, same two
  pre-existing visual spray failures; lightning/delay/thunder/pause checks pass.

Evidence/scoped checkpoint and [rain/thunder mix preview](evidence/rain-thunder-2026-10-10/review.html):
`docs/evidence/rain-thunder-2026-10-10/`. No UI/camera/physics/backend change,
phone attachment check, device listening, Android export/install, full Validate
or deployment. Owner thunder realism/volume and device acceptance remain.

## Strong thunder and lower rain, 2026-10-10

The owner still finds thunder barely noticeable and requests a properly strong
sound with quieter rain. SND30 raises the clap and rolling body substantially:
soft source peak control lets the master reach0.22RMS rather than the earlier
peak-constrained0.102; thunder gain0.65 to1.0. Combined measured/source gain
increase is10.404dB. Recorded texture,7.5s duration, source provenance,
delay/spacing/pitch, fade/pause/focus/mute and protected output ceilings remain.
SND31 lowers rain0.36818182 to0.28 (another23.95%/-2.378dB), keeping the exact
owner-supplied rain loop. Wet tires remain deferred. No new bus or dependency.

Changed files: `game/track/storm_weather.gd`, `scripts/build_storm_thunder.py`,
`game/assets/audio/{storm_thunder.wav,storm_thunder.wav.import,storm_thunder_manifest.json}`,
ambience `NOTICE.txt`, `game/tests/capture_thunder_audio.gd`,
`scripts/review_thunder_audio.py`, this page, `DEVELOPMENT_STATUS.md`,
`docs/PHASE_0_PLAN.md`. Capture/review accepts a separate evidence directory and
a stronger-volume contract; previous checks remain for historical captures.
The stronger check additionally requires dominance in the final mixed output,
not only a raw source reference. No earlier failing invariant is loosened.

Actual commands:

- `python scripts/build_storm_thunder.py`: final/repeat build exact SHA256
  `eed0fce82f87b15743e806bc1d0a9fe4472254a46efb628dcf60260bce0159ad`;
 7.5s/661,544 bytes, assetRMS -13.152dBFS and peak -2.414dBFS.
- Pinned `scripts/dev.ps1 Import`: exit0.
- `TestScript -ScriptPath res://tests/test_wet_road_audio.gd`:40 checks,
  zero failures, clean exit.
- `TestScript -ScriptPath res://tests/capture_thunder_audio.gd -Graphical`
  with `--evidence-dir=res://../docs/evidence/strong-thunder-2026-10-10`:
 19 checks, zero failures; one delayed strike with actual race presentation,
  default engine/music, pause and Vehicle mute.
- `python scripts/review_thunder_audio.py --evidence-dir
  docs/evidence/strong-thunder-2026-10-10 --stronger`:zero failures.
  Native thunder strongest50ms -8.155dBFS; final output strongest50ms
 -12.108dBFS,8.015dB above the engine's -20.123dBFS reference. Rain -36.408dBFS;
  output peak0.706/roughly-3dBFS, below ceilings. Paused PCM zero; mute leaves
  only music within0.002dB RMS. Rain/47 vehicle WAV/mixer/wishlist hashes exact.

Evidence/source checkpoint and [stronger thunder mix](evidence/strong-thunder-2026-10-10/review.html):
`docs/evidence/strong-thunder-2026-10-10/`. No phone attachment check,
device listening, Android export-install, full Validate, physics/camera/backend
or deployment. Earlier two visual spray failures were not rerun in this
volume-only correction. Owner loudness/realism and device acceptance remain.

## Owner thunder with bass enhancement, 2026-10-10

SND32: owner rejects the prior thunder and supplies
`freesound_community-thunder-big-wav-29190.mp3`, requesting bass enhancement.
The16.056s recording now replaces thunder, keeping its buildup, clap and tail.
A +6dB low shelf below180Hz and gentle25Hz subsonic cleanup add weight; existing
soft peak control/level matching protect headroom. No added/synthetic layers
or previous3.2kHz high cutoff. Final bass40–180Hz relative to400–2000Hz rises
4.089dB after mastering. Rain0.28/thunder1.0 gains, delay/spacing/pitch and
Vehicle volume/mute/pause/focus remain. Wet tires remain deferred.

Original321,120-byte MP3 is untouched; source copy/decoded float receipt and old
thunder assets remain outside exports. Filename attribution only:
`freesound_community`; licence metadata not supplied, no previous CC0 licence
inherited. Source SHA256 `12b96eaaae5e4528237bb67b7dcc9eeb4a00e3dcc11d424b29146cd71007c0ca`;
master `768b2f761ca6638ab46df007cde0f7e38a16d12b4e04391a4f9a56aa004e09b4`,
1,416,184 bytes. Existing47 vehicle WAVs/rain/StormWeather/wet mixer/wishlist
hashes match the before-task snapshot.

Changed files: `scripts/build_storm_thunder.py`,
`game/tests/decode_storm_rain_source.gd`, `game/tests/capture_thunder_audio.gd`,
`scripts/review_thunder_audio.py`,
`game/assets/audio/{storm_thunder.wav,storm_thunder.wav.import,storm_thunder_manifest.json}`,
ambience `NOTICE.txt`, this page, `licenses/ASSETS.md`,
`DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. Capture duration derives from
the longer clip so the complete tail is exercised. The owner-bass review keeps
final-output dominance and all pause/mute/headroom guards while verifying the
new spectral requirement; the old stronger-body revision retains its own check.

Actual commands (engine uses pinned `scripts/dev.ps1`):

- Copy the explicitly supplied Downloads MP3 to non-exported source storage;
  source hash pinned. `TestScript -ScriptPath res://tests/decode_storm_rain_source.gd`
  with `--source-path=res://../build/storm_thunder_sources/owner-thunder-29190`:
 708,070 mono float frames at44.1kHz, exit0.
- `python scripts/build_storm_thunder.py`: final/repeat identical SHA256.
  `Import`: exit0.
- `TestScript -ScriptPath res://tests/test_wet_road_audio.gd`:40 checks,
  zero failures/exit0;117 ObjectDB shutdown warnings retained.
- `TestScript -ScriptPath res://tests/capture_thunder_audio.gd -Graphical`
  with `--evidence-dir=res://../docs/evidence/owner-thunder-bass-2026-10-10`:
 19 checks, zero failures; actual race presentation/default music, one delayed
  cue, full-tail capture, paused pending cue and Vehicle mute.
- `python scripts/review_thunder_audio.py --evidence-dir
  docs/evidence/owner-thunder-bass-2026-10-10 --owner-bass`: zero failures;
  final strongest50ms -11.460dBFS (8.663dB above engine), output peak0.701;
  paused PCM zero, mute leaves only music within0.004dB RMS. Bass increase and
  preserved hashes confirmed.

Evidence/scoped checkpoint and [owner thunder/bass mix](evidence/owner-thunder-bass-2026-10-10/review.html):
`docs/evidence/owner-thunder-bass-2026-10-10/`. No device listening/attachment
check, Android export-install, full Validate, physics/camera/backend or deployment.
Owner source/bass approval and target-speaker listening remain; earlier visual
spray failures are outside this audio replacement.
