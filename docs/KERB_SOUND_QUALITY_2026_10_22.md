# Kerb sound quality — 2026-10-22

KQ01-KQ03/G01/R01/Q01 refine SND53. The owner clarified that the Compact's
kerb effect lacked sound quality, rather than volume. This supersedes the
earlier Compact-only +4.5 dB loop/+3 dB entry adjustment, which is removed.

The shared kerb waveform is now an original dry tyre/body design: short broad
rubber contacts, several damped body modes, restrained upper-mid contact detail
and small irregular secondary compressions. It replaces the old falling sine
notes. Six contacts per second at native pitch retain the established thud
cadence. Soft offline compression controls isolated spikes without erasing the
attacks. This is authored sound design, not a field recording.

Both the PCM master and actual runtime Ogg are replaced. The new master measures
−18.51 LUFS; decoded playback −18.47 LUFS; the old master −18.50 LUFS. The
comparison therefore changes tone/texture at closely matched loudness. The shared
effect is used by all cars. Original entry bump, speed pitch, wheel/sweep/hold and
silence gates, Desert suppression, existing voices, 24 MiB stream cache and canonical
driving remain. Concurrent snowbank audio and bridge work are preserved.

The 7.5-second mono 44.1 kHz/16-bit master remains 661,544 bytes. Its Ogg is
156,513 bytes, 91,183 bytes larger than the previous derivative. Actual decode
has exactly 330,750 frames and 37.32 dB SNR. All 50 other bank WAVs and eight
other bank Oggs retain their pre-task hashes; a repeat build reproduces all 60.

Actual commands, with pinned Godot 4.7.2.stable.official.ed1daf0bf:

| Command | Actual outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One master, repeat hash exact. |
| `python scripts/encode_kerb_audio.py --wsl-ffmpeg /home/ville/.local/share/bmt-music-tools/ffmpeg --reference docs/evidence/kerb-quality-2026-10-22/before/game/assets/audio/vehicles/kerb_roll.wav --report docs/evidence/kerb-quality-2026-10-22/encoding.json` | Exact duration, waveform/spectrum/envelope/peak/seam and matched-loudness gates pass; repeat Ogg exact. Existing offline WSL tool only. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180` | Exit 0; revised WAV and Ogg imported. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-dir=res://../docs/evidence/kerb-quality-2026-10-22'` | **88 checks, zero failures**, including actual Game callback, all cars and 12 native recordings. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd -Graphical -RenderingMethod gl_compatibility` | **1,469 checks, zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_desert_soft_sand_audio.gd` | **67 checks, zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_audio_loops.gd` | **208 checks, zero failures**, including the actual Ogg playback loop. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/kerb-quality-2026-10-22/loop-continuity.json` | **42 loops, zero failures**, including repeated wraps. |
| `python scripts/review_kerb_refinement.py --evidence-dir docs/evidence/kerb-quality-2026-10-22` | **12 native captures pass**; original low-mid/headroom/pause/no-false-kerb assertions retained. |
| `python -m py_compile scripts/kerb_audio_mastering.py scripts/build_vehicle_audio.py scripts/encode_kerb_audio.py scripts/review_kerb_refinement.py` | Exit 0. |
| `python build/checkpoint_kerb_quality.py` / scoped `git diff --check` | 15-file task-only binary/text patch reverse-applies cleanly; whitespace check exits 0. Concurrent snow source/provenance is excluded from the patch. |

Native mixed crossing/riding/three-speed peaks: 0.4356/0.3997/0.5185, with silent
pause tails. Game crossing: two bumps, original 0.6012 peak loop gain and no
collisions. These are digital checks, not subjective listening acceptance.

Listen to `docs/evidence/kerb-quality-2026-10-22/before-after.wav`: old cue
0–3.2 seconds, pause, revised cue 3.9–7.1 seconds. The cuts have short fades;
the source cues are matched within 0.03 LUFS. The same folder retains native
mixed/isolated WAVs, logs, scope/rebuild/encoding reports and task-only checkpoint.

Changed files: `scripts/{kerb_audio_mastering,build_vehicle_audio,encode_kerb_audio,review_kerb_refinement}.py`,
`game/vehicle/vehicle_audio.gd`, the two `kerb_roll` assets, bank/compression
manifests and notices, `licenses/ASSETS.md`, this receipt, `DEVELOPMENT_STATUS.md`
and `docs/PHASE_0_PLAN.md`. No tests or invariants were weakened. Existing NumPy
and FFmpeg remain offline tools. WSL initially required sandbox escalation;
test storage uses task-specific APPDATA under the workspace.

Remaining acceptance: restart the local client and assess the revised timbre
while driving, especially on phone speakers/headphones. No phone attachment
check/device test, APK/export/install, backend/account mutation or deployment.
