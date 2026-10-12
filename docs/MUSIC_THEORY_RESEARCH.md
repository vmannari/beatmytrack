# Music theory and racing-background research - 2026-10-08

MUS34/MUS20-MUS33/Q01. The owner rejects the clear-theme cue as beginner piano
and requests research into music theory and effective background/racing scores.
The completed [research and revised composition brief](music/research/2026-10-08-background-racing.md)
compares primary Ori/Trackmania/Forza accounts, theory texts and original studies.
The [14-source register](music/research/2026-10-08-sources.json) records access and
evidence limits; restricted abstracts are identified.

Resulting direction: establish rhythmic rock ensemble character first; use
coordinated kit/bass/guitar motion, sparse foreground motifs, purposeful phrase
variation, harmonies with continuity and subtle atmospheric texture. Preserve
confidence-based development, short-race responsiveness, one-minute exceptional
payoff, shared biome/menu identity, existing loop guarding and silent hover.
The research provides a concrete brief, not a new finished composition or proof
of what will sound good. The prior cue is now recorded as rejected.

Changed files: research/report/source register, `docs/music/STATE.md`, detailed
round, the clear-theme study's superseding rejection notice, its local manifest
rejection metadata, status and phase entries. All audio, runtime/simulation,
vehicle/menu SFX, settings, player files and backend remain unchanged. No new
samples, generation, external dependency, purchases, reference-audio download or
music conditioning. No game/UI/art/camera change or new screenshot requirement.

Actual inspection: read the adaptive-music skill/evidence/craft notes, project
state/status/phase plan and composer/render/controller sources. `web.run`
searched and opened the registered primary accounts/texts/studies. The alternate
Forza7 press-release page had a decoding failure; the publicist-posted original
release was read instead. Unrelated search results and fan opinions were excluded
from conclusions. There was no acoustic reference listening.

Actual local command audit:

```powershell
Get-Content tools/music_generator/render_theme_sketch.py
Get-Content tools/music_generator/compose_flow_performance.py
Get-Content game/soundtrack/audio_world.gd
Get-FileHash tools/music_generator/render_theme_sketch.py -Algorithm SHA256
# Read the saved role targets and compute20*log10(piano/other-role).
.tools/review/Scripts/python.exe build/music/music-theory-research-2026-10-08/finalize.py
git diff --check -- docs/music/STATE.md docs/CLEAR_THEME_STUDY.md DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md
```

The score audit finds fixed nominal piano-event gains and role targets placing
piano11.285dB over kit/9.702dB over lower guitar. These are code/nominal energy
findings, with the previous solo/full RMS difference as supporting evidence;
they do not establish perceived loudness or every cause of the owner's feedback.

Verification checks source-register/schema/link coverage, archived/current audio
and music-code hashes, rejection metadata, task-only patch reverse-application and
scoped whitespace. Numerical/functional tests cannot validate this research's
musical proposals; no new Godot/audio-generation test was run. No phone attachment
check/device audio test, export/install, full Validate, backend action or deployment.
The overarching soundtrack goal and artistic/device acceptance remain unfinished;
this requested research phase is complete.

The initial whole-runtime checksum failed because concurrent vehicle-audio work
added an Impacts-volume preference entry. Recorded before/current source and diff
prove that removing that one entry reproduces the exact original fingerprint;
all other bytes are checked. The change is preserved/excluded from this research
checkpoint; no claim of a wholly unchanged shared runtime file is made.

Final local result:14 unique source IDs/URLs with complete report-link coverage,
restricted access identified;37 game audio hashes and study audio hash match,
music code matches its original fingerprint after the explicitly audited concurrent
entry is separated. Rejection metadata,9-file text-patch reverse-application and
scoped whitespace checks pass. No Git staging/commit was performed.
