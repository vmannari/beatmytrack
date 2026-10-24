# Subtle thuds beneath the cobblestone kerb sound — 2026-10-23

KST01-KST03/R01/Q01: the owner wants a subtle “thud-thud-thud” underneath
the cobblestone sound. Revision8 retains the recorded compact-car clatter and
adds a short, rounded recorded vehicle-body transient six times per second at
native pitch. This supersedes revision7's no-pulse design.

The existing CC0 Nox vehicle body source supplies the thud: cut0.92–1.045s,
95–420Hz shaping,4ms attack,36ms decay and12ms release, with small level
variations. Its layer RMS is0.38 of the cobblestone layer (8.40dB lower).
The original cobblestone excerpt/timing remains; the added body cadence is
authored. No generated tone/noise or new recording download is used. Source
identities, cuts, license and hashes are in the bank manifest and notices.

The fixed master gain matches prior loudness: master−18.53LUFS, actual
decoded Ogg−18.48LUFS, previous master−18.49LUFS. The first calibration was
−18.17LUFS and was adjusted before import. This is a character change, with
no runtime gain increase. Existing speed pitch gives3.9–8.1 body pulses/second
across its0.65–1.35 range. The7.5-second mono44.1kHz loop remains shared by
all cars, including Compact. Runtime GDScript, physics-contact onset, entry
events, contact/pause/Desert gates and concurrent shared-output work remain.

Actual checks use pinned Godot4.7.2.stable.official.ed1daf0bf and isolated
APPDATA under `build/kerb-subtle-thud-2026-10-23/native-user`:

| Actual command | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One661,544-byte master. Final repeat: all60 bank WAV/Ogg hashes exact. |
| `python scripts/encode_kerb_audio.py --wsl-ffmpeg /home/ville/.local/share/bmt-music-tools/ffmpeg --reference docs/evidence/kerb-subtle-thud-2026-10-23/before/game/assets/audio/vehicles/kerb_roll.wav --report docs/evidence/kerb-subtle-thud-2026-10-23/encoding.json` | 330,750 exact decoded frames;36.12dB SNR;161,931-byte Ogg. Original spectrum/envelope/headroom/seam/loudness gates pass. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180` | Exit0; both updated assets imported. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-dir=res://../docs/evidence/kerb-subtle-thud-2026-10-23'` | Final89checks/zero failures;12native recordings; actual Game crossing has2entry bumps and0.60138peak rumble gain. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_audio_loops.gd` | 208checks/zero failures. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/kerb-subtle-thud-2026-10-23/loop-continuity.json` | 42loops/zero failures. |
| `python scripts/review_kerb_refinement.py --evidence-dir docs/evidence/kerb-subtle-thud-2026-10-23` | 12native captures pass;93.63% low-mid energy; silence/headroom/no-false-kerb checks retained. All58other WAV/Ogg files exact. |
| `python build/audit_kerb_subtle_thud.py` | Recorded layer−8.40dB;48pulses/eight seconds; native6Hz low-band envelope modulation0.01782→0.15397. Actual master matches summed layers within16-bit quantization. Applied preview has12ms boundary fades only. |
| `python -m py_compile scripts/kerb_audio_mastering.py scripts/build_vehicle_audio.py scripts/review_kerb_refinement.py` | Exit0. |
| `python build/checkpoint_subtle_thud_kerb.py` and scoped `git diff --check` | Task-only binary/text checkpoint reverse-applies; other bank/compression rows exact; whitespace passes. |

Initial native run:88checks/one failure, because the old actual-Game fixture
started crossing before the current asynchronous preparation finished. The
fixture now disables automatic stepping before attach, waits up to30seconds
for real preparation and explicitly asserts readiness before the same crossing.
No production behavior or existing assertion was removed/weakened. Both the
initial log and final passing run are retained.

Changed files: `scripts/kerb_audio_mastering.py`, `scripts/build_vehicle_audio.py`,
`scripts/review_kerb_refinement.py`, the focused kerb test fixture, the two kerb
assets, bank/compression manifests and notices, `licenses/ASSETS.md`, this
receipt and the two project status docs. Evidence, applied preview, native
captures, original working-tree snapshots, hashes and checkpoint are under
`docs/evidence/kerb-subtle-thud-2026-10-23/`. The shared Git index is untouched;
concurrent work is preserved.

Restart the PC client to replace cached audio. Owner listening acceptance
while driving remains; signal checks do not establish subjective quality.
No phone/tablet attachment check or physical-device test, APK/export/install,
live account/backend mutation or deployment was performed by this task.
