# Owner-selected looping menu music, 2026-10-11

Requirements MUS36 (supplied recording as menu background), MUS37 (continuous
loop), SND05 (saved volume), MUS35/SND33 (silent racing), G01/R01/Q01 (pinned
engine, simulation separation and actual verification). MUS36/MUS37 identify
this request locally; existing IDs retain their prior scope.

`Exploration 3_take-3.mp3` is the owner's selected complete mix. The original
120-second, 48 kHz stereo MP3 is preserved outside the export root at
`archive/music/menu-exploration-2026-10-11/Exploration 3_take-3.mp3`.
No generation or runtime service was added. Provider, original authorship and
distribution license were not supplied; the manifest records this uncertainty
separately from explicit authorization for local integration and loop editing.

The export uses 44.1 kHz stereo 16-bit uncompressed PCM and the existing
`PcmAudioLoop` cyclic guard. The recorded fade-out is trimmed: source end
112.847528s; onset/spectral matching selects the closing overlap. A 1.995125s
constant-sum cosine blend joins the ending to the opening; playback starts at
that opening offset and repeats every 110.852404s (4,888,591 frames). A quiet
waveform slope places the cut. Original dynamics/tempo are retained with uniform
gain 0.806636 (about -1.87 dB), export peak -3.00 dBFS, RMS -20.54 dBFS and
mono RMS ratio 0.77888. The encoded wrap delta is 0.00036621. These are technical
measurements, not an assertion of subjective musical seamlessness.

The runtime `MENU_ASSET` points to the new file independently of the older bank.
The old menu master, interface sounds, PB/results events and race silence remain
preserved. The new recording follows existing menu/results playback, music
volume, app focus suspension and return behavior. No UI or visual change.

Changed/new files: `game/soundtrack/audio_world.gd`,
`game/assets/audio/menu_exploration_v1/{exploration_menu_loop.wav,.wav.import,manifest.json,NOTICE.txt}`,
`scripts/prepare_menu_exploration.py`, `game/tests/test_soundtrack.gd`,
`game/tests/capture_menu_exploration.gd`, the archived source, this document,
music state/status/phase records and `docs/evidence/menu-exploration-2026-10-11/`.

Actual commands and outcomes (entry point `scripts/dev.ps1`, pinned Godot
4.7.2.stable.official.ed1daf0bf):

| Command | Outcome |
| --- | --- |
| Local WSL FFmpeg `-i <archived MP3> -ar 44100 -c:a pcm_f32le build/menu-exploration-source.wav` | Decoded exactly 120s/5,292,000 stereo frames. |
| Existing WSL music Python `scripts/prepare_menu_exploration.py --analyze`, then without options | Analyzed source; exported loop, manifest and two-loop/transition previews. Final PCM assertions pass. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Final normal-access import exits 0; explicit lossless import required. |
| `... -Action TestScript -ScriptPath res://tests/test_soundtrack.gd` | 1,158 checks, zero failures: native frame guard, exact source/export pin, existing lifecycle/settings, canonical separation. |
| `... -Action TestScript -ScriptPath res://tests/test_biome_music_off.gd` | 42 checks, zero failures; existing 51-object shutdown warning remains. All five race/practice themes stay music-free. |
| `... -Action TestScript -Graphical -ScriptPath res://tests/capture_menu_exploration.gd` | Final 9 checks, zero failures: two native wraps, explicit focus pause/resume, delivered mute. |
| Existing WSL music Python `scripts/prepare_menu_exploration.py --review-native` | Two native captures peak 0.59491; minimum 50ms RMS -32.415/-32.276 dBFS through recording; no silent interval/clipping; muted delivered Master is exactly zero. |
| `... -Action Doctor` | Engine/matching templates found; ADB device list empty. No attached phone. |

Initial failures were retained in logs: restricted Godot certificate/log access
and restricted ADB home; first import chose QOA, violating the existing PCM
assertion, corrected to `compress/mode=0`; a natural boundary step failed the
seam bound, corrected by selecting a nearby quiet waveform slope. Capture mute
initially measured a pre-mute Music effect, corrected to delivered Master.
Desktop focus caused an intermittent capture pause/level dip; the final fixture
holds capture focus per frame and separately tests explicit focus notifications.
One attempted SceneTree override ended without a test summary and was corrected
to `process_frame` wiring; it is not counted as a passed check. No invariant was
removed to accept a failing implementation.

Evidence includes `audio-analysis.json`, `native-audio-review.json`,
`loop-transition.wav`, `two-loops.wav`, two `godot-wrap-*.wav` captures and
`godot-muted.wav`. Review the transition preview and normal menus through
several repeats at the user's preferred volume. Subjective listening was not
performed through an audio-perception route. Phone speakers/mono and real
device focus/navigation acceptance remain pending. No Android export/install,
full Validate, physics regression, backend change, deployment or purchase.

The workspace contains substantial pre-existing work including untracked
soundtrack runtime files. A task-only patch against saved pre-task files and a
hash checkpoint are kept with this evidence; unrelated work is not staged or
committed by this task.
