# Sports-rock soundtrack rewrite - 2026-10-08

Later2026-10-08: the owner rejects this candidate as irritating and requests a
complete recompose. The active bank is now the [performed phrase score](PERFORMED_FLOW_SOUNDTRACK.md).
This document and its recordings preserve the rejected version's evidence.

The owner rejected the 144 BPM clean-band score as too mellow and requested
sportier 80s-rock instrumentation with atmospheric development, while retaining
the background role. The new original menu/race composition is installed in the
existing bank. [Listen to all five palettes and actual game mixes](evidence/sports-rock-2026-10-08/audition.html),
or [compare old/new at equal loudness](evidence/sports-rock-2026-10-08/comparison/index.html).

| Requirement | Implementation |
|---|---|
| MUS28: recompose sporty/energetic 80s-rock character | New D/C/G/A riff harmony, muted electric guitar, driven responses, finger bass, firm acoustic backbeat, gated room, short fills and chorus-guitar width. |
| MUS29: atmospheric background music | Quiet written string and original offline analog-style pad textures; short motif statements separated by space, controlled top end and constant family gain. No reference-game recordings or melodies. |
| MUS30: retain adaptive identity and delivery | Same D-E-A-F# motif, race144/menu112 BPM, six synchronized layers and five biome colours; original confidence/PB/rival/gate/setback/breath contracts and quiet activation cues. |
| MUS20-MUS27/G01/R01/Q01/V06 | Existing presentation observer, exact loops, car-audio headroom, silent hover/focus, provenance, saved volume controls and scoped evidence remain. |

The opening has forward-moving bass and muted riff fragments. Earned parts fill
the gaps; kit and melodic responses then join, followed by chorus guitars,
atmospheric support and the reserved octave motif. This changes writing and
articulation, rather than only increasing gain. The new Grass 90-second preview
measures -24.98 LUFS versus the previous -23.82; both audition copies use
constant gain to approximately -22 LUFS (-22.00/-22.01 measured).

Grass carries the warm band; Desert adds dry colour/tremolo/gravel; Winter uses
piano/shimmer/space; Night has tighter filtered guitar/kit; Storm has heavier
drum/guitar colour and quiet wind-derived rhythm. They remain one musical world.

Changed files: `tools/music_generator/render_sports_rock.py`,
`verify_locked_in.py` and toolkit `README.md`; the 37 audio exports plus
manifest/notice in `game/assets/audio/locked_in_v1/`; test/capture destination
overrides in `game/tests/test_soundtrack.gd` and `capture_locked_in.gd`; this
document, `LOCKED_IN_SOUNDTRACK.md`, `music/STATE.md`, round feedback,
`DEVELOPMENT_STATUS.md`, `PHASE_0_PLAN.md` and `licenses/ASSETS.md`.
The destination overrides affect fixture evidence only.

Sources/masters/exports remain under `build/music/sports-rock-2026-10-08/`.
Renderer refuses to overwrite preserved masters. Task-start bank, source files
and earlier band masters/mixes remain intact. Input134 files/59,199,072 bytes
retain immutable Karoryfer CC0 provenance; VSCO CE support, Nox gravel and
project-authored wind retain prior clearance. Newly authored atmosphere is
baked offline; no runtime AI/API/synth or new runtime dependency. Source/sampler
and output SHA-256s are in the manifest. Shipping audio21,664,144 bytes.

Actual commands, using the pinned Godot4.7.2 build:

```powershell
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/render_sports_rock.py
# Copy exports to the existing bank, then import before testing/capture.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import
$env:BMT_MUSIC_EVIDENCE='res://../docs/evidence/sports-rock-2026-10-08'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_soundtrack.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_soundtrack.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_score_flow.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp
# Four actual capture runs: story/palettes/events/menu, respectively140/100/60/80-second bounds.
$env:BMT_SCORE_CAPTURE_SEGMENT='story'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_locked_in.gd -Graphical -CommandTimeoutSeconds 140
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/verify_locked_in.py --evidence-dir docs/evidence/sports-rock-2026-10-08
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/review_score_revision.py docs/evidence/locked-in-score-2026-10-07/mix4/pine-clean-story.wav docs/evidence/sports-rock-2026-10-08/pine-clean-story.wav --out docs/evidence/sports-rock-2026-10-08/comparison
.tools/review/Scripts/python.exe build/music/sports-rock-2026-10-08/browser_review.py
.tools/review/Scripts/python.exe build/music/sports-rock-2026-10-08/checkpoint.py
```

Actual results: soundtrack1158 headless/1163 graphical, flow29 and App99 checks
pass. Four real mixer capture segments pass4/10/5/3 checks. Verification covers
37 exports, 160 combinations and18 recorded master/music buses with zero clipped
samples; strongest combination -9.091 dBTP, minimum mono RMS ratio0.961.
Race loops are exactly2,352,000 stereo frames at44.1kHz/53.333333s; menu1,512,000
frames/34.285714s. Maximum decoded boundary delta0.007596 remains below the
existing0.008 assertion. Actual exceptional final entry completes at59.964s;
the requested two-beat breath, paused palette tails and hover/focus silence
are verified. Recorded music-story RMS -27.275dBFS versus car+music master
-19.210dBFS; combined peak -6.085dBTP. These measures establish headroom,
not perceptual car masking or music quality.

Browser checks load nine playable previews, exercise seeks/exclusive playback
and both90s comparison files without page errors. The generated review-page
screenshot was inspected. Game UI is unchanged; actual Settings captures are
retained from the graphical soundtrack tests. Runtime fixtures use scripted
confidence/sector/PB signals and the actual car-audio model; no natural player
PB or agent subjective listening is claimed.

The first follow-up flow command used an invalid `-TestScript` parameter;
corrected to `-ScriptPath`. Restricted WSL and Godot user-log startup attempts
failed; approved local tool execution completed the checks. A quoted Python
metrics one-liner also failed; native JSON inspection supplied final metrics.
Initial checkpoint checks exposed UTF-8 BOM and trailing blank-line formatting;
the text encoding/endings were corrected. No check/assertion was weakened.
Import finished before recorded story startup.

`protected-before/after.json` show the three music runtime scripts,
vehicle simulation/state, race rules/session and app unchanged from task start.
Concurrent `game/core/game.gd` changes are retained and excluded from the music
checkpoint. The task-only text patch plus audio hashes provide the reviewable
checkpoint; shared dirty Git state is preserved. Final checkpoint covers14 text
files/48 changed files, reverse-application check passes; Python compilation and
scoped diff whitespace checks pass. No Git staging or commit was performed.

Remaining acceptance: owner listening for energetic character, guitar/drum
texture, atmospheric restraint, low-state comfort and repeated-race fatigue;
natural imperfect/PB/rival/creator driving; headphones and phone speakers/mono,
device decode/thermal performance. No phone attachment check or phone audio test,
Android export/install, full Validate, backend action or production deployment.
The new score is an installed audition candidate; AAA artistic acceptance is pending.
