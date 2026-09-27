# Reference arc R2: two options per stage

2026-09-27. MUS03/MUS06/MUS09/MUS10 and V03/V05/Q01. Owner authorizes the next
iteration and emphasizes multiple options at every stage so drives differ.
User wording: "Also not that each stage must have multiple options so that each
drive feels different. Anyway, proceed to generate the next iteration".
Interpreted "not" as "note", consistent with the existing per-drive variation
request; this assumption was stated before generation.

## Musical experiment

Baseline: rejected first Magenta concept/endpoint auditions. New conceptual
brief is recorded in `2026-09-27-reference-arc.md`: intimate atmosphere to grounded
roots groove, confident guitar drive, urgent hooks, tension and anthemic payoff.
Instrumental, repeated-play suitability and existing runtime recovery remain.

Six stages × two options × 16 seconds = 12 complete mix studies. Working family
`night_signal_r2`; 120 BPM and D-minor/F-major direction are prompt requests, not
measured musical contracts. Each option uses different instrumentation or
articulation as well as a recorded style-mapper seed. No copied recordings,
melodies, vocal material or external conditioning audio are used.

| Stage | A | B |
|---|---|---|
| Focus | Fingerpicked electric guitar, distant organ | Felt piano, airy guitar, low strings |
| Momentum | Clean twang, walking bass, rim clicks | Slightly gritty guitar, firmer bass/snare pocket |
| Drive | Trading guitar phrases | Low crunchy riff, harmonized replies |
| Flow | Palm-muted guitar into ringing chords | Syncopated bass, chiming guitars, keyboard answer |
| Lift | Low riff beneath an ascending lead | Piano octaves, bass movement, luminous synth answer |
| Breakthrough | Brass-like synth fanfare, guitar answers | Harmonized guitar anthem, broad keyboard chords |

These are intended differences, not claims that the model followed every
instruction. All effective prompts fit the 127-token limit without truncation.
Shared labels, key, tempo or prompt gestures do not establish motif continuity
or additive compatibility. This round tests direction and per-stage choices;
no family is artistically approved or promoted into the game.

## Workbench

`R2 · All A` / `R2 · All B` load six stage assignments from one complete review
batch. `R2 · New drive` chooses one option at each stage; an identical consecutive
draw changes one choice. Choices remain fixed through intensity, collision and
restart. The existing setup export can preserve a preferred combination. Random
selection occurs only in this standalone tool; canonical game randomness and
runtime audio are unchanged. The user can still manually audition each take.

## Commands and evidence

```powershell
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py layers --config tools/music_generator/configs/reference_arc_r2.yaml
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/review_iteration.py build/music/raw/reference_arc_r2/20260927-221452-85e11b3d/manifest.json
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/test_toolkit.py
.tools/review/Scripts/python.exe tools/music_generator/test_iteration_browser.py
```

`review_iteration.py` invokes the adaptive-music skill's `scripts/review_pack.py`
six times, one A/B group per stage. Constant gain only, -20 LUFS requested target
and -2 dBTP ceiling; a group's target is lowered if headroom requires it. Source
files/hashes are preserved. Measured loudness and true peaks accompany each
review asset in its manifest. This is audition balancing, not a production mix.

FFmpeg was absent. `sudo -n apt-get install -y ffmpeg` could not proceed without
a password; Windows pip download failed certificate validation. No protections
were disabled. WSL pip successfully downloaded `imageio-ffmpeg==0.6.0`; its
FFmpeg 7.0.2 Linux binary was extracted into the user's local tool directory.
No system packages or generation-venv dependencies changed.

Final generation/review metrics, exact hashes, original wording, scoped approval
status and browser checks are recorded in `docs/evidence/music-r2/` and the round
JSON. Generated WAVs remain in ignored `build/music`, outside the export root.
The workbench screenshot is an actual browser capture.

Actual outcome: all 12 raw files are distinct, finite/non-silent 16-second 48kHz
stereo WAVs. Maximum prompt length is 92 tokens; none were truncated. No raw
near-full-scale samples were detected. All six A/B review groups pass measured
loudness/headroom verification; maximum review true peak is -2.0 dBTP. The
toolkit suite passes 10 tests and the R2 browser suite passes 9 checks, including
real nonzero audio, all stage switches, fixed choices through collision, and a
forced repeated random draw that must produce a changed lineup. Screenshot
inspected. JAX allocator retry warnings recurred during loading but generation
completed with exit code 0; review and browser verification also exited 0.

Changed files: R2 YAML config; generator variant-prompt support and its test;
review helper adapter; workbench selection buttons and focused browser test;
README, music state, round/evidence and project status notes. Existing unrelated
winter work and local skill-installation files are outside this checkpoint.

Remaining acceptance: user listening of each A/B pair, stage/transition fit,
fatigue and clipping assessment, then selection/recreation of a composition with
verified shared timing and harmony. No subjective listening claim, Godot build,
Android export or device test; phone attachment was not checked. No runtime
collision/reset/recovery behavior changed.
