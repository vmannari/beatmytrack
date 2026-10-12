# Continuous owner grass rustles — 2026-10-11

Owner supplies `dragon-studio-grass-rustling-05-511299.mp3` and
`dragon-studio-grass-rustling-04-511301.mp3` and requests continuous,
speed-dependent grass feedback. **SND57**, refining SND55/SND54/SND47/SND09
with G01/R01/Q01/V06 audio presentation. This uses the supplied clips, not the
previously requested/unavailable Soundsnap recording.

Both MP3s are copied into offline build inputs and decoded by pinned
Godot4.7.2.stable.official.ed1daf0bf.05 is35,328 bytes/1.104s/48,687 mono float
frames;04 is57,600 bytes/1.800s/79,380 frames, both at44.1kHz. Their amplitude
analysis shows quiet starts and fading ends around individual rustles. Preserve
the active recording sections0.32–0.85s and0.33–1.32s, alternating variable
0.45–0.72s excerpts with120ms cosine joins and200–300ms advance. Overlap the
rustles rather than replay their quiet ends. Slow circular500ms energy control
keeps the bed continuous while retaining fine detail. Final140–4200Hz EQ,
cyclic power join, headroom/DC removal and16-bit dither produce an **11.5s,
1,014,344-byte**, mono PCM loop. No generated noise or body tone is added.

Grass already grows louder with speed/wheel contact/slip. The new shared
presentation pitch helper additionally increases rustle pace from0.70 to1.35
over0.5–32m/s, using a smooth bounded curve. Both the immediate post-step
contact cue and normal render mix use this same helper. Stationary/air/roll/
countdown/pause/departure rules and the120Hz grass response remain; first60FPS
contact still reaches86.5% of settled gain. Runtime simulation, handling,
geometry, controls/rules/backend are unchanged. The Engine-sidechain mixer fix
is retained. All **48 other WAVs**, including all engines, accepted kerb thuds,
crashes/rail scrape/gravel/desert, are hash-exact.49 bank clips/23 players remain.

Source provenance: owner-provided local files; Dragon Studio attribution is
inferred from filenames and not independently verified. No third-party license
document was supplied. Public searches for the two exact IDs returned no results;
do not claim CC0 or a verified publisher page. Owner-authorized local use and
encoded/decoded/derivative checksums/decoder are retained in the manifest/NOTICE.
Original encoded and float files stay outside the export root. This is local
sound implementation; no production release/deployment occurs here.

Changed files: `scripts/owner_grass_mastering.py`, `prepare_owner_grass_source.py`,
`build_vehicle_audio.py` (new scoped `--grass-only`), `offroad_audio_mastering.py`
(full/offroad builds use the same owner-grass renderer),
`game/vehicle/vehicle_audio.gd`, `game/tests/decode_owner_grass.gd`/UID,
`test_grass_kerb_audio.gd` (louder/faster outcomes across all five cars),
`scripts/review_owner_grass.py`, `game/assets/audio/vehicles/grass.wav`,
`manifest.json`, `NOTICE.txt`, this document, `DEVELOPMENT_STATUS.md`,
`docs/PHASE_0_PLAN.md`. Other accepted audio runtime behavior is retained.

Actual commands/results:

| Command | Outcome |
| --- | --- |
| Copy the two explicitly supplied Downloads MP3s into `build/vehicle_audio_sources/owner_grass_*.mp3` | Both files copied; originals untouched. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/decode_owner_grass.gd` | Exit0; both pinned-engine decodes complete. |
| `python scripts/prepare_owner_grass_source.py` | Two source records/float WAVs registered with exact hashes. |
| `python scripts/build_vehicle_audio.py --grass-only` | One loop/1,014,344 bytes; repeat all49 WAV hashes exact. |
| `python build/reconstruct_owner_grass_baseline.py` | Prior grass WAV reconstructed from snapshotted mastering; **exact task-start SHA256 asserted**, current bank untouched. Necessary because initial snapshot retained its hash rather than its WAV. |
| Same pinned launcher, `-Action Import` | Exit0; grass/scripts imported. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,454 checks/zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | **67 checks/zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -TestArgument '--offroad-review=res://../docs/evidence/owner-grass-rustle-2026-10-11'` | **106 checks/zero failures**, all-car speed/intensity/pace, prompt contact/partial fringe, kerbs/lifecycle/canonical separation;30 native mixed/isolated captures. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/owner-grass-rustle-2026-10-11/loop-continuity.json` | **42 loops/zero failures**, three wraps and no embedded gaps. |
| `python scripts/review_owner_grass.py` | **30 captures pass**, both exact supplied sources, live continuous grass sweep, prompt onset/headroom/pause tails/no false kerb,48 other WAVs exact and Engine sidechain retained. |
| `python -m py_compile scripts/owner_grass_mastering.py scripts/prepare_owner_grass_source.py scripts/build_vehicle_audio.py scripts/offroad_audio_mastering.py scripts/review_owner_grass.py` | Exit0. |

Master RMS−18.79dBFS/peak−4.93dBFS. Native grass-entry/moving grass mix peaks
0.279/0.373; isolated grass sweep peak0.337. Every final150ms pause tail exactly
silent. Actual Game kerb still yields two contact bumps/rumble gain0.401/zero
collisions. Auditions are controlled native contact/presentation poses and a
gradual speed sweep, not full races or physical-device measurements.

Evidence: `docs/evidence/owner-grass-rustle-2026-10-11/`, source metadata,
before hash ledger/exact reconstructed prior grass WAV, thirty native auditions,
onset/continuity/rebuild/source/headroom audits, actual logs, scoped Git-format
patch and checkpoint hashes. Shared index/unrelated work untouched. Existing
direct-hit collision regression unchanged; no whole-suite-green claim.

Remaining acceptance: restart an existing game to load the new loop, then owner
listening on actual grass and phone speakers/headphones. **No phone listening/
device test, Android export/install, fullValidate or deployment performed.**
