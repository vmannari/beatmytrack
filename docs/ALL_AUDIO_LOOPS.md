# Complete looping-audio audit — 2026-10-10

Owner request: recurring artefacts remain; review **all** looping tracks and make
them properly loopable. **SND36** covers complete inventory, source seams,
sustained envelopes/pitch and native playback boundaries. **SND02–SND06,
SND19/SND24–SND35/G01/R01/Q01/V06** preserve provenance, local lifecycle,
headroom, simulation separation and actual verification/device limits.

The audit covers **85 unique assets**: 40 vehicle loops, recorded rain, cicadas,
the stereo menu loop, one retained inactive synthetic rain loop, 30 retained
shipping biome Ogg loops and 11 export-excluded historical Ogg loops. There are
44 PCM and 41 Ogg loops; 74 are shipping candidates. Biome music stays disabled
during driving, the rejected wet-road voice stays deferred and the legacy rain
stays inactive. No audio files were deleted or reenabled.

The main defect is shared playback setup. WAV loops supplied no cyclic frame
beyond the final source frame; fractional-pitch interpolation could dip into
resource padding at every wrap, even with a clean source seam. A constant-level
native mixer witness reproduces the defect. In the full audit run, unguarded
0.73/1.0/1.85 pitch tests have 36/20/40 glitch samples; every guarded test has
**zero**. An earlier run differs at unity pitch but also fails at fractional
pitch: the bug is not diagnosed solely by inspecting the source WAV.

`PcmAudioLoop.prepare` now supplies an exact cyclic mono/stereo frame, keeps the
original frame count as the loop endpoint and leaves the source resource intact.
Vehicle, legacy tire diagnostic, menu, rain and cicada factories use this shared
setup. Existing menu/rain/cicada guards are preserved through consolidation.
The regression checks mono/stereo at 0.35/0.73/1.0/1.85/2.85 pitch, plus every
PCM source/factory. One-shots retain nonlooping behavior.

Source fixes address the independent defects revealed by the audit:

- All five engine families use eight-second whole-cycle sustained recorded
  pulses. The four other cars' old files repeated rev/stop transients and large
  level changes. Only valid complete forward-moving source cycles contribute;
  a restrained original offline noise bed retains broad mechanical/air colour.
  Its fundamental band is excluded to avoid reintroducing slow phase modulation.
  The compact idle pair is now sustained too; its previous four mid/high WAVs
  remain byte-identical. Other cars are revoiced and require ear acceptance.
- Each vehicle's three orders share one ratio to its existing sound-model RPM
  anchors, so neighboring layers agree. A 0.35–2.85 pitch range covers every live
  anchor overlap; the previous cap flattened a fading lower layer. This changes
  audio presentation only, never physical gearing, power, grip or timing.
- Surface/wind/water use correlation-aware power-preserving joins and circular
  energy shaping. Road is 12 s; wind/water 11.5 s; granular rolling/spray/loose
  material 16 s; debris 17.5 s. Natural short granular detail remains.
- Tire endpoints remain **exactly zero** at a natural quiet crossing. The old
  pair of 2 ms tapers is removed, avoiding a repeated fade-to-silence while
  preserving the existing handling diagnostic invariant.
- The same owner rain 20–41 s excerpt, RMS target, peak cap and playback gain
  remain; its one-second overlap now preserves power. No EQ/layers are added.
  The retained synthetic rain loses its short seam fade and uses lossless import.
  Its generator is invoked with `--rain-only`, preserving the thunder one-shot.

All 30 engine source-envelope minima are better than **-0.914 dB** relative to
their median over 40 ms windows, compared with a worst original **-18.144 dB**.
The maximum final 20 ms engine-order 5th–95th-percentile span is **0.014179 Hz**.
Every source seam/native Ogg wrap passes the derivative continuity bound.
All sustained nonmusical loops pass the dropout/headroom checks; music rests and
musical phrase variation are not flattened or falsely classified as failures.
The final 85-entry audit has **zero failures**.

[Review all source wraps, native vehicle mixes and the matched wind comparison](evidence/all-audio-loops-2026-10-10/audition.html).
[Full numerical audit](evidence/all-audio-loops-2026-10-10/audit.json).
Five native engine-bus captures use actual vehicle presentation with 65% load,
equal-power neighboring RPM layers, 26 seconds of sustained playback and one
paused second. Each observes wraps `[9,4,2,9,4,2]`; the audible mid/high load/coast
layers cross at least two boundaries. No shifts, state mutation, measured dropout
or clipping occur. Peaks are 0.232–0.287; every final half-second is exactly silent.
These are controlled states, not completed races or acoustic microphone captures.

**38 audio files change; 64 remain byte-identical**, including all music, cicadas,
all 17 one-shots and the compact's previous four mid/high sustains. The vehicle
bank is 31,301,752 bytes versus 12,853,390 before (~17.6 MiB more across all cars).
Only the selected six engine loops and existing surface voices load for a race;
no new voice, runtime synthesis, provider, dependency or network request is added.
NumPy/FFmpeg are existing offline tools. More PCM memory/storage and changed
noncompact timbres remain material device/listening acceptance items.

Changed files: `game/platform/pcm_audio_loop.gd` and UID;
`game/vehicle/{vehicle_audio,tire_audio}.gd`;
`game/soundtrack/audio_world.gd`;
`game/track/{storm_weather,night_ambience}.gd`;
`scripts/{build_vehicle_audio,compact_audio_mastering,surface_audio_mastering,
audio_loop_mastering,build_storm_rain,generate_storm_audio,review_audio_loops}.py`;
changed WAVs/imports, vehicle/rain manifests and notices;
`game/tests/{audit_audio_loops,test_audio_loops,capture_audio_loop_mix}.gd`/UIDs;
this document, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`,
`docs/PHASE_0_PLAN.md` and evidence. No physics/camera/race contracts change.

Actual commands use pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

| Command | Actual result |
| --- | --- |
| `… dev.ps1 TestScript -ScriptPath res://tests/audit_audio_loops.gd -TestArgument '--probe-only'` | Reproduces unguarded sample dips; cyclic guards remove them. |
| `… dev.ps1 TestScript -ScriptPath res://tests/audit_audio_loops.gd` | All 41 retained Ogg loops decoded across their actual wraps; no gameplay activation. |
| `python scripts/build_vehicle_audio.py` | 47 mastered files; 36 changed looping WAVs, all seven vehicle one-shots exact. |
| `python scripts/build_storm_rain.py` | Owner rain crossfade corrected; same source/excerpt/gain/RMS. |
| `python scripts/generate_storm_audio.py --rain-only` | Repairs only the retained legacy rain; thunder hash exact. |
| `… dev.ps1 Import` | Final imports pass; PCM is lossless, including legacy rain. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_audio_loops.gd` | Final **208 checks, zero failures**. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,446 checks, zero failures**, including exact 960-tick simulation equivalence. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_soundtrack.gd` | **1,156 checks, zero failures**; menu timing/guard and disabled driving music retained. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_wet_road_audio.gd` | **41 checks, zero failures**. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_night_ambience.gd` | **25 checks, zero failures**. |
| `… dev.ps1 TestScript -ScriptPath res://tests/capture_audio_loop_mix.gd -Graphical` | All five actual vehicle mixes, repeated wraps and state snapshots; zero failures. |
| `… dev.ps1 TestApp` | **99 checks, zero failures**; isolated app/race/results/records flow. |
| `… dev.ps1 TestHandling` | **88 checks, zero failures**, including tire zero endpoints and exact historical diagnostic replays. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd` | **445 scripts, zero failures** at the recorded run. |
| `python scripts/review_audio_loops.py --listening` | Final **85 loops, zero failures**, five native capture checks and complete source-wrap listening evidence. |
| Repeat all three offline builders and compare audio SHA-256 | Final **102/102 media hashes identical**; sources preserved. |
| Existing music skill `scripts/review_pack.py` via local Ubuntu FFmpeg | Peak-safe constant-gain wind A/B pack, common -20 LUFS/-1 dBTP ceiling; no limiting or source edits. |
| Scoped `git diff --check` and reverse-check of task patch | Exit 0; review checkpoint valid without modifying the shared index. |

Intermediate audit flags for classic high load/coast (noise leaking into the
fundamental band) were corrected without relaxing the 0.3 Hz variation bound.
The inventory grew from 84 to 85 when the retained legacy rain was included.
The first restricted WSL query was denied; the permitted default PATH lacked
FFmpeg. The existing `~/.local/share/bmt-music-tools/ffmpeg` resolved that;
an inline path-quoting failure and Windows CRLF helper error were corrected with
a file-based LF entry point. Final review-pack processing passes. Receipts and
source snapshots are retained; no dependency was downloaded or installed.

The technical music review follows
[`bmt-adaptive-music`](../.agents/skills/bmt-adaptive-music/SKILL.md)'s Technical
workflow, preserving rejected/retained material and not claiming subjective
listening, artistic approval or production readiness. No visible UI changed;
playable audio is the presentation evidence. No phone attachment check, device
listening/memory/performance test, Android export/install, full Validate, backend
operation or deployment was performed. Restart the local game to load new
resources; installed Android builds remain unchanged. Remaining acceptance:
owner listens during actual driving across surfaces/cars and long sustained
slides, pause/focus/retry/rewind, then confirms speakers/headphones/Bluetooth and
device memory/performance. Natural texture and real contact/gear events can still
repeat; digital correctness is not a guarantee of subjective sound quality.
