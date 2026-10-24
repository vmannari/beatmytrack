# Cobblestone-style kerb sound — 2026-10-23

KCB01-KCB03/G01/R01/Q01: the owner rejects the separate-bump preview and asks
for the sound of driving on a cobblestone street. That reference supersedes the
earlier synthetic six-beat thuds and the rejected rumble-strip/bump auditions.

The game's shared kerb loop now derives from
[Car rolling on cobblestone.wav by orlandorizo](https://freesound.org/people/orlandorizo/sounds/591078/).
The author describes a small compact car on bumpy cobblestones, recorded inside
a Suzuki Alto with a Zoom H5; the primary page lists CC0. The public HQ MP3
preview was downloaded and decoded, not the original 48 kHz/24-bit WAV.

The 8–16 second excerpt keeps actual uneven tyre/body contacts and their timing.
Broad 100–6500 Hz shaping reduces sub-bass cabin energy; one cyclic join and
fixed master gain preserve the changing clatter. No synthesized tones, fixed
pulse train, added noise bed or envelope levelling. Both master and runtime Ogg
are updated; source identities/hashes are in the bank and compression manifests.

Existing gain, speed pitch, first-physics-contact start, sweep/hold, silence and
Desert fences remain. No runtime GDScript is changed. Shared Windows mix/snow
work, other vehicle sounds, voice/cache bounds and canonical driving remain.
This shared cue changes for all cars, using the owner's cobblestone character
reference; it is not presented as a circuit-kerb field recording.

Actual validation with pinned Godot 4.7.2.stable.official.ed1daf0bf, isolated
APPDATA beneath `build/kerb-cobblestone-2026-10-23/`:

| Command | Outcome |
| --- | --- |
| Public Freesound source-page/HQ MP3 download; existing WSL FFmpeg mono decode | CC0 verified; exact source hashes retained. |
| `python scripts/prepare_kerb_cobblestone_audition.py --source build/kerb-cobblestone-2026-10-23/source.wav --encoded-source build/kerb-cobblestone-2026-10-23/source.mp3 --source-page build/kerb-cobblestone-2026-10-23/source-page.html --output docs/evidence/kerb-cobblestone-audition-2026-10-23 --wsl-ffmpeg /home/ville/.local/share/bmt-music-tools/ffmpeg --register-source` | Raw-character preview and reproducible source registration. |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One 661,544-byte/7.5-second mono 44.1 kHz/16-bit master; repeat exact. |
| `python scripts/encode_kerb_audio.py --wsl-ffmpeg /home/ville/.local/share/bmt-music-tools/ffmpeg --reference docs/evidence/kerb-cobblestone-2026-10-23/before/game/assets/audio/vehicles/kerb_roll.wav --report docs/evidence/kerb-cobblestone-2026-10-23/encoding.json` | 330,750 exact decoded frames; 36.74 dB SNR; original spectrum/envelope/headroom/seam/loudness gates pass. Ogg 161,396 bytes. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180` | Exit0; revised WAV/Ogg imported. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-dir=res://../docs/evidence/kerb-cobblestone-2026-10-23'` | **88 checks, zero failures**, 12 native recordings and actual Game crossing. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd -Graphical -RenderingMethod gl_compatibility` | **1,469 checks, zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_audio_loops.gd` | **208 checks, zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_desert_soft_sand_audio.gd` | **67 checks, zero failures**. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/kerb-cobblestone-2026-10-23/loop-continuity.json` | **42 loops, zero failures**, repeated wraps retained. |
| `python scripts/review_kerb_refinement.py --evidence-dir docs/evidence/kerb-cobblestone-2026-10-23` | **12 native captures pass**, original low-mid/headroom/pause/no-false-kerb assertions retained. 50 other WAVs exact. |
| Python compilation of the changed offline scripts | Exit0. |
| `python build/checkpoint_cobblestone_kerb.py` / scoped `git diff --check` | 14-file binary/text patch reverse-applies cleanly; other bank/compression rows stay exact; whitespace check exits0. |

Final master −18.49 LUFS/decoded −18.44 LUFS, previous master −18.51 LUFS.
Initial uncalibrated encoding failed the retained matched-loudness assertion;
the fixed source filter/gain was corrected before import. No assertion was
weakened. Final low-mid energy is 92.64%. Native mixed crossing/riding/three-speed
peaks are 0.2426/0.2541/0.3942, with exact silent pause tails. Game still gives
two entry bumps and no physical crashes. Repeat build: all 60 bank WAV/Ogg
hashes exact; only the two kerb files differ from the pre-task bank baseline.

Evidence: `docs/evidence/kerb-cobblestone-2026-10-23/`, including applied sound,
source receipt, native recordings, logs, encoding/rebuild checks and a task-only
binary/text patch plus hash ledger. Changed files: kerb mastering/build/review
scripts, the new source-preparation script, two kerb assets, bank/compression
manifests and notices, asset credits, this receipt and the two project status docs.
The shared Git index is untouched; no paid asset or runtime dependency is added.

Restart the PC client to replace cached audio. The earlier auditions are not
installed. Owner timbre acceptance while driving remains; digital checks establish
integrity, not subjective quality. No phone attachment check/device test, updated
phone build/APK/export/install, backend/account mutation or deployment.
