# Original adaptive soundtrack — 2026-10-07

The owner requests menu/race soundtracks, driving-responsive development reaching
the final tune around one minute in an approximately 90-second clean race, proper
loops, unobtrusive repeated-play music, Ori/Hollow Knight as aesthetic references
and appropriate menu feedback. This supersedes the 2026-10-06 soundtrack absence.
The rejected native renderer remains archived; no reference-game audio, melodies
or conditioning files are used.

[Listen to the menu, two race concepts and actual Godot mixes](evidence/adaptive-score-2026-10-07/audition.html).
This is an integrated first listening slice. **Musical approval remains pending.**
No agent listening or achieved AAA quality is claimed.

## Requirements

MUS11–MUS17 identify this new owner request; MUS01–MUS10 describe historical native
renderer contracts. G01/R01/Q01/V06 continue to apply. SND01 soundtrack absence is
superseded only for the authorized new score.

| ID | Delivered behaviour |
| --- | --- |
| MUS11 | Continuous menu theme through navigation, creator/settings/account/garage/results; retained menu position through page changes and race returns. |
| MUS12 | Two related five-layer race arrangements, authored from one written harmony/melody/grid per family; performance develops the theme without restarting its foundation/clock. |
| MUS13 | Layer entries at 12/24/40/56 qualifying seconds, next two-second bar, four-second fades. Ideal fixture reaches full at 60s; actual recorded mixer at **61.940s**. Full arrangement loops for longer races/practice. |
| MUS14 | Every race layer: 120 BPM, 32 bars, exactly 2,822,400 stereo frames/64s at 44.1kHz. Menu: 90 BPM, 32 bars/85.333333s. Circular note/room tails, encoded frame/seam checks and actual playback wraps. |
| MUS15 | Quiet recorded wood/piano focus, selection, confirmation and back sounds; three bounded voices, throttled focus/activation, disabled/invisible controls excluded. Driving touch controls do not make menu clicks. |
| MUS16 | Settings → Audio: separate Music/Vehicle/Interface sliders, one-percent steps, Reset audio/Apply; validated atomic per-profile saves. Defaults 70/100/70%; music mute preserves car feedback. |
| MUS17 | Pinned cleared recordings, original score, immutable source/export hashes and licences, preserved masters, bounded decoders, headroom/mono/mix checks and actual output evidence. No paid generation, native extension, runtime model/API or new runtime dependency. |

## Score and runtime

**Open Horizon** is the reflective minor treatment for Grass, Winter, Night and
Storm. **First Light** is a brighter modal answer to the same melodic contour for
Desert. These are two bounded concepts for listening; distinct approved scores
for every biome are not claimed. Workshop is a quieter, slower menu treatment.

The foundation carries low/mid piano statements, bowed cello and moving harmony.
Current adds harp responses; Motion adds bowed movement/soft hand percussion;
Flight adds wind answers and horn colour; Arrival expands the familiar theme in
strings. The 32-bar arc has statement, answer, departure and return, phrase rests
and suspensions. Later layers develop existing material; state changes do not
swap tracks or accelerate tempo.

These are **additive runtime layers**, deliberately authored on the same written
clock, rather than independently generated mixes. No Magenta generation was used
because the installed prompting adapter cannot establish exact part compatibility.
The offline renderer performs recorded multisamples with bandlimited pitch
conversion, small fixed performance offsets, bow/breath envelopes and baked room
tails. Pitch inspection caught the library's differing octave conventions:
piano/harp use middle C=C4; bowed/wind folders use C3. Corrected before integration.
The initial mix was measured too quiet against vehicle audio; mix 2 rebalances
layers and applies common family gain. Both master/preview versions are preserved.

The read-only observer uses motion, real contact strength, road cells, route
direction/bend and missing-gate state. Speed expectation drops at bends; braking
and controlled drifts can retain credit. Stopping, reverse/off-road/missed-section
or rolled-car states do not earn full music. Poor motion gradually reduces earned
progress at up to 0.22s/s. Contacts ≤1.5 retain progress; stronger impacts shed up
to eight earned seconds with 1–3s recovery. Retreats start on a bar and fade; the
foundation and clock continue. These music-balance values await owner review.

No observer writes touch physics/input/timing/rules/tracks. Tick deltas supply
progress and the audio player supplies bar boundaries. Rewind freezes playback
while selecting, retains momentum/clock on resume and uses a tick high-water mark
to avoid double-earning scrubbed time. Retry restarts the foundation. Countdown
plays it without earning progress; finish crossfades to the retained menu position.
Focus loss/backgrounding pauses output/events; driving retains its ordinary resume
action.

One AudioStreamSynchronized player begins all five exact-length looping parts
together. One menu decoder, five race decoders and three interface voices bound
soundtrack/UI overlap to nine sources during the 0.85s context fade, in addition
to the vehicle system. No live synthesizer/reverb is added. Headless verifier/tests
do not allocate output decoder playbacks; graphical tests verify real playback.

## Provenance and settings contract

49 instrument recordings plus licence/readme total **92,058,475 bytes**, pinned
to immutable VSCO 2 CE tree `440300901dfe9275fd84e0b7763af1f8443ae62e`.
[Source repository and CC0 licence](https://github.com/sgossner/VSCO-2-CE).
Credits retain Sam Gossner/Versilian Studios, Simon Dalzell/Ivy Audio and
Elan Hickler/Soundemote. Original notes/arrangements are authored for this project.

Existing local WSL Python 3.12.3 supplies NumPy 2.3.5, SciPy 1.18.1,
SoundFile 0.14.0 and the existing FFmpeg. Score/config, source URLs/hashes,
tool versions, constant gains and output hashes are in
`game/assets/audio/score_v1/manifest.json` and preserved
`build/music/score-v1/masters*/provenance.json`. Shipping audio comprises 11 Vorbis
loops and four mono 16-bit interface WAVs: **8,864,180 bytes**. Notices/manifests
are included; sample sources/WAV masters remain outside export.

Optional finite numeric `music_volume`, `vehicle_volume`, `interface_volume` in
[0,1] extend the existing schema-2 preference allowlist. Older profiles retain
defaults without migration/deletion. Invalid values still fail LocalRecords
validation. Canonical physics/rules/content identities and models/configs are
unchanged.

## Actual commands and results

All engine commands used `scripts/dev.ps1` and pinned
`4.7.2.stable.official.ed1daf0bf`. Logs retain failed intermediate attempts.

| Actual command | Outcome |
| --- | --- |
| `Invoke-WebRequest https://api.github.com/repos/sgossner/VSCO-2-CE/git/trees/master?recursive=1 …`; `python tools/music_generator/fetch_score_sources.py` | Pinned index and 51 cleared files; later offline hash recheck passes. Sandbox network denial and absent source-path guesses corrected before fetch. Fetcher now bootstraps the immutable index itself. |
| `wsl -d Ubuntu -- bash tools/music_generator/scripts/render_score_v1.sh --inspect` | Spectral pitch/library-version inspection; octave mismatch corrected. Initial nested shell quoting failed; script entry point fixes it. |
| `… render_score_v1.sh` and `… render_score_v1.sh --revision 2` | Original/mix-2 renders; sources/masters preserved. Mix-2 exports promoted to runtime; initial exports retained under `build/music/score-v1/exports-v1`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import`; `… CheckScript -ScriptPath res://soundtrack/audio_world.gd` | Pinned import/parse succeeds after Windows certificate-store sandbox denial was resolved with normal host access. |
| `… TestScript -ScriptPath res://tests/test_soundtrack.gd` | Final **1,065 checks, 0 failures**: loops, timing/recovery/road/gate/rewind qualification, race lifecycle, volumes and **960 ticks of exact canonical state/input equivalence**. |
| `… TestScript -ScriptPath res://tests/test_soundtrack.gd -Graphical` | Final **1,069 checks, 0 failures**, actual playback/pause/UI and two inspected Audio-settings screenshots. Direct-autoload parser and typed-fixture errors corrected. |
| `… TestScript -ScriptPath res://tests/capture_soundtrack.gd -Graphical -CommandTimeoutSeconds 360` | **11 checks, 0 failures**, eight actual bus recordings, complete menu/race wraps, full arrival at 61.94s, car/music recovery and menu feedback. Capture-print typo corrected. Signals/car states are scripted fixtures, not a claimed perfect player replay. |
| `wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/verify_score_v1.py` | **15 assets, 32 layer combinations, eight actual captures; zero clipped samples**. Worst source/subset true peak -9.424dBTP. Actual car/music mix -6.14dBTP, RMS -19.44dBFS. Paused tails zero; interface-only music bus silent. Measurements/listening page written. |
| `… TestApp`; `… TestScript -ScriptPath res://tests/test_vehicle_audio.gd`; `… TestRecords` | Final **99 / 1,434 / 54 checks**, zero failures, clean exit. Freed-control deferred callbacks repaired via instance IDs. Verbose logs found paused Vorbis playback leaks on headless shutdown; no-playback headless policy/explicit shutdown correct them. No failing invariants removed. |
| `… TestMenus`; `… TestRewind`; `… TestHandling` | **48 / 57 / 88 checks**, zero failures, including exact historical handling replays. |
| `… Validate -QuickValidation` | Exit 0; import/startup/focused driving/catalog/menu gate passes. Driving72/catalog21/menu48 checks pass. Driving fixture emits **27 ObjectDB leaked-instance warnings**, retained in its log. Full Validate was not run. |
| `… Doctor` | Matching engine/templates; **DN2103 attached**. Device detection is not an audio acceptance test. |
| Local Playwright/Edge review via `.tools/review/Scripts/python.exe` | Seven previews load metadata/play; seek markers and exclusive playback work, zero final script errors. Normal preview-switch AbortError was handled after the first browser check caught it. Screenshot/JSON retained; no listening claim. |
| `python build/music/score-v1/make_checkpoint.py`; `git apply --reverse --check --ignore-whitespace docs/evidence/adaptive-score-2026-10-07/scoped-change.patch`; scoped `git diff --check` | Review checkpoint: 46 task text changes, 61 pinned source/export files; reverse applicability and whitespace checks exit 0. Existing Windows CRLF notices retained. Audio/evidence binary hashes are recorded separately. |

## Files and checkpoint

Runtime: `game/soundtrack/audio_world.gd`, `driving_score_progress.gd` and `.uid`s;
`game/assets/audio/score_v1/*`; `game/core/app.gd`, `game/core/game.gd`,
`game/project.godot`, `game/default_bus_layout.tres`, `game/export_presets.cfg`,
`game/ui/menu_style.gd`, `menu_icon.gd`, `settings_page.gd`,
`game/persistence/local_records.gd`.

Tools/tests: `tools/music_generator/fetch_score_sources.py`, `render_score_v1.py`,
`verify_score_v1.py`, `scripts/render_score_v1.sh`, toolkit README;
`game/tests/test_soundtrack.gd`, `capture_soundtrack.gd` and `.uid`s;
`scripts/dev.ps1` adds `-EngineVerbose` for pinned-engine diagnostics.
Docs: this file, Music State, phase/status notes, asset ledger.

Screenshots: [desktop](evidence/adaptive-score-2026-10-07/settings-audio-1280x720.png)
and [compact](evidence/adaptive-score-2026-10-07/settings-audio-960x540.png).
Measurements, runtime trace, command logs, baselines, task-scoped text patch and
hash inventory are under `docs/evidence/adaptive-score-2026-10-07/`. Extensive
unrelated workspace changes are preserved. The scoped patch is the reviewable
Git checkpoint; no all-workspace commit was made.

## Remaining acceptance

Owner listening of identity, instrumental quality, opening comfort, full-state
restraint, tonal preference, transitions and repetition fatigue in real driving;
repeated restarts/long imperfect runs/rewind; phone speaker/headphone/mono and
minimum-volume balance for every car/biome; Android decoder cost/thermals,
focus/ad/Bluetooth/audio-route interruptions and packaging. A naturally driven
perfect race has not been captured; qualifying mix signals are explicitly scripted.

DN2103 was detected, but **no phone audio test, APK export/install, full Validate,
backend/cloud rollout, purchase or production action** was performed. Technical
checks do not assert AAA, subjective listening or artistic approval.
