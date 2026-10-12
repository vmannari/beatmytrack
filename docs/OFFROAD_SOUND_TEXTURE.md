# Uneven offroad sound — 2026-10-11

Owner accepts the synthesized kerb thuds and next requests less white-noise-like
offroad feedback. **SND54**, refining SND09/SND47 with G01/R01/Q01/V06 sound
presentation separation. This slice replaces **grass and gravel rolling**.
The accepted kerbs, crashes, rail scrape and existing desert sounds remain exact.

Grass/gravel previously used recorded noise with bright filtering and100ms
envelope leveling, which flattened most surface variation. New original offline
designs combine low100–650Hz rolling, smooth uneven tyre pressure, irregular
overlapping soft body/rubber loading, and short restrained crunch/rustle grains.
Grass is softer and bassier, with75–1500Hz final EQ; gravel retains more granular
detail up to2300Hz. There is no fixed kerb rhythm, field ambience or runtime
synthesis. Keep the designed variation instead of100ms leveling; retain cyclic
power joins, headroom,16-bit dither and unchanged continuity assertions.

Both loops are7.5s/661,544 bytes, mono44.1kHz/16-bit PCM. Grass spectral power
centroid930→279Hz, gravel1008→361Hz. Power above2200Hz falls from5.87% to
approximately zero for grass, and6.41% to0.0253% for gravel.100ms RMS-envelope
variation increases1.81%→19.34% and6.34%→14.56%, respectively: uneven surface
feedback instead of a leveled hiss. These measurements demonstrate the waveform
change, not owner listening acceptance or physical realism.

No runtime feedback/gain/pitch/grass-entry timing, material detection, canonical
simulation or geometry change. Five-car first-frame grass gain remains86.5% of
settled level at60FPS. All **47 other WAVs** are hash-exact; bank49 clips/race23
bounded players are retained. This reuses two loop voices with no extra event
pool. Existing gravel debris events remain independent. Source credits are
historical for the two replaced loops; generator/seed/derivative hashes are in
the bank manifest. Both full and new scoped `--offroad-only` mastering use the
same renderer; the scoped path needs no owner-crash/rail source archives.

Changed files: `scripts/offroad_audio_mastering.py`, `build_vehicle_audio.py`,
`surface_audio_mastering.py`, `review_offroad_audio.py`,
`game/tests/test_grass_kerb_audio.gd` (optional offroad audition mode/isolated
gravel bus and5/18/36m/s grass/gravel captures),
`game/assets/audio/vehicles/grass.wav`, `loose.wav`, `manifest.json`, `NOTICE.txt`,
this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.
No product UI, runtime GDScript, physics, rules or backend changes.

Actual commands/outcomes:

| Command | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --offroad-only` | Two clips/1,323,088 bytes; repeat all49 WAV hashes exact. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Exit0; pinned4.7.2.stable.official.ed1daf0bf imports revised sounds/fixture. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,454 checks/zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | **67 checks/zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -TestArgument '--offroad-review=res://../docs/evidence/offroad-texture-2026-10-11'` | **90 checks/zero failures**, all-five-car prompt grass, partial/creator-fringe contact, kerb/lifecycle/canonical isolation/Game callback;24 native mixed/isolated recordings. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/offroad-texture-2026-10-11/loop-continuity.json` | **42 loops/zero failures**, existing joins and embedded-gap checks retained. |
| `python scripts/review_offroad_audio.py` | **24 captures pass**, spectrum/uneven envelope/source provenance, audibility/headroom/pause/no false kerb, grass onset within100ms of actual contact timestamps,47 accepted WAVs exact. |
| `python -m py_compile scripts/offroad_audio_mastering.py scripts/build_vehicle_audio.py scripts/surface_audio_mastering.py scripts/review_offroad_audio.py` | Exit0. |

Native grass-entry/grass-speed/gravel-speed mixes peak0.276/0.373/0.361. Every
final150ms pause tail exactly silent. Actual Game kerb behavior remains two
bumps, rumble gain0.401 and zero collisions. Three-speed auditions use controlled
contact/presentation poses, not complete races or physical-device acoustic tests.
Existing direct-hit collision regression is unchanged; no whole-suite-green claim.

Evidence: `docs/evidence/offroad-texture-2026-10-11/`, with before asset hashes,
twenty-four native auditions, first-frame/contact timing, spectrum/continuity/
headroom/rebuild audits, actual logs, scoped Git-format patch and checkpoint
hashes. Shared Git index/unrelated work untouched. Remaining acceptance is owner
listening during real road-to-grass/gravel transitions and through phone speakers/
headphones. **No phone listening/device test, Android export/installation,
fullValidate or deployment performed.**
