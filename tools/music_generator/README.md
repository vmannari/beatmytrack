# Local music studio

## Current complete recompose (2026-10-08)

The active [performed phrase score](../../docs/PERFORMED_FLOW_SOUNDTRACK.md)
replaces the rejected sports-rock riffs. Original eight-bar writing is rendered
with the existing local MRT2 MIDI controls, measured/retimed to a160 BPM race
clock, and split into complementary components of ONE performance. They are
not isolated instrument stems. The gentler112 BPM menu uses uncompressed PCM
and a cyclic endpoint guard. [Listen](../../docs/evidence/flow-recompose-2026-10-08/audition.html).

Composition/preparation: `compose_flow_performance.py`,
`render_flow_performance.py`, `repair_flow_loops.py`. Masters and failed versions
remain preserved; use a new directory for another revision. Verify using
`verify_locked_in.py --evidence-dir docs/evidence/flow-recompose-2026-10-08`.
Godot checks/captures use the existing `BMT_MUSIC_EVIDENCE` override; the new
`capture_menu_continuity.gd -Graphical` records two wraps through actual menus.
Details/source drift/failed repairs/provenance/owner and device acceptance are
recorded in the delivery document. Previous sections retain historical work.

## Current sports-rock rewrite (2026-10-08)

The owner rejected the clean band as too mellow. The new original composition
uses muted/overdriven electric-guitar riffs, chorus guitar, firmer acoustic drums
and quiet string/analog-style atmosphere. Race144/menu112 BPM and the existing
confidence controller stay intact. [Listen and compare at equal loudness](../../docs/evidence/sports-rock-2026-10-08/audition.html).
Requirements, evidence and acceptance: [SPORTS_ROCK_SOUNDTRACK.md](../../docs/SPORTS_ROCK_SOUNDTRACK.md).

```powershell
# This renderer refuses to overwrite archived masters. Use a fresh round for another rewrite.
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/render_sports_rock.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/verify_locked_in.py --evidence-dir docs/evidence/sports-rock-2026-10-08
$env:BMT_MUSIC_EVIDENCE='res://../docs/evidence/sports-rock-2026-10-08'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_soundtrack.gd -Graphical
# Capture each bounded segment with BMT_SCORE_CAPTURE_SEGMENT=story/palettes/events/menu.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_locked_in.gd -Graphical -CommandTimeoutSeconds 140
```

Sources/masters/exports are under `build/music/sports-rock-2026-10-08/`; the
installed bank retains its stable `locked_in_v1` resource paths. Previous band
masters/evidence and the task-start bank remain preserved. The optional evidence
environment variable changes test output destinations only. Owner and phone
listening remain pending.

## Current band/flow score

The current direction is [The music locks in with you](../../docs/LOCKED_IN_SOUNDTRACK.md): recorded band, one four-note motif, confidence progression and five palettes. Race144/menu112 BPM. [Listen](../../docs/evidence/locked-in-score-2026-10-07/audition.html).

```powershell
python tools/music_generator/fetch_band_sources.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/render_locked_in.sh --inspect
# Preserve existing mixes; use a fresh revision for another render.
wsl -d Ubuntu -- bash tools/music_generator/scripts/render_locked_in.sh --mix-revision 5
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/verify_locked_in.py
```

Current renderer source/output and the targeted beat-synchronous Desert repair are traceable in the installed manifest. Earlier paragraphs below retain historical music studies. Runtime checks use `test_soundtrack.gd` and `test_score_flow.gd`; real capture uses `capture_locked_in.gd -Graphical`, optionally with `BMT_SCORE_CAPTURE_SEGMENT=menu/story/palettes/events` for bounded runs. Musical approval remains pending.

The new race tempo is144 BPM, menu112 BPM. Race loops are32 bars/53.333333s;
two-bar fades and two-beat breaths follow that clock. The highest layer remains
confidence/clean-sector gated and arrives around60s on exceptional runs. Source
and rendered versions1-4 plus the targeted tremolo repair remain preserved.


## Original game soundtrack (2026-10-07)

Current revision: [upbeat mix 3](../../docs/UPBEAT_SOUNDTRACK.md), following the
owner's rejection of the melancholic opening/world. Hover and keyboard focus are
silent; selection/confirm/back cues remain. [Listen to the new revision](../../docs/evidence/upbeat-score-2026-10-07/audition.html).

The game uses the original recorded-instrument score in
[ADAPTIVE_SOUNDTRACK.md](../../docs/ADAPTIVE_SOUNDTRACK.md). The retired native
synthesizer and unapproved RT2 studies below remain historical. Listen to the
current [menu/race review](../../docs/evidence/adaptive-score-2026-10-07/audition.html).

Free CC0 source setup/rendering, with existing local WSL tools:

```powershell
python tools/music_generator/fetch_score_sources.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/render_score_v1.sh --inspect
# Prior mixes are preserved. Use a fresh revision/evidence directory for another render.
wsl -d Ubuntu -- bash tools/music_generator/scripts/render_score_v1.sh --upbeat --revision 4 --evidence-dir docs/evidence/score-round4
# Validate the current installed revision and its actual captures.
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/verify_score_v1.py --evidence-dir docs/evidence/upbeat-score-2026-10-07
```

New renders go into `build/music/score-v1/masters-vN` and `exports-vN`. Promote a
reviewed export into `game/assets/audio/score_v1`, retaining provenance/prior
masters. The validator reads installed assets and actual capture files. Runtime
test/capture use `scripts/dev.ps1 TestScript` with `res://tests/test_soundtrack.gd`
or `res://tests/capture_soundtrack.gd`; the latter needs
`-Graphical -CommandTimeoutSeconds 360`. Artistic approval remains pending.

Run from the Windows repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/music_generator/launch.ps1
```

Open <http://127.0.0.1:18765>. Windows Python 3.10+ is sufficient for the workbench;
it uses standard-library HTTP and browser Web Audio, with no npm/CDN dependency.
The server listens only on loopback and exposes its UI and `build/music` audio.
Port 8765 is reserved on this machine; `-Port` can select another port.
Stop the server with Ctrl+C. The VS Code task **Music: Open workbench** does the same.

## Generate, listen and keep

The opening **Create music** screen now runs Magenta RT2 directly. Give the take
a working title, write a prompt, choose its duration and optionally assign a
musical state. **Generate a take** uses the existing local WSL GPU installation.
Keep the server running while it works; browser reloads are safe.

Listen with the waveform/player, then **Save to library** or **Discard take**.
Discarded takes can be restored from the inbox. In **Your library**, select a
saved track, edit its name or state and click **Save changes**. Assignments persist
on disk and appear in **Mix lab**. **Earlier recordings** contains previous
experiments that you can audition and save. State labels organize music; they do
not change the generated audio or automatically integrate it into the game.

Back up `build/music` to retain both the recordings and
`workbench/library.json`. Prompt drafts are kept in browser local storage.
The server exposes no source deletion action. Generation errors retain the
prompt and expose retry information. See [implementation and actual checks](../../docs/MUSIC_STUDIO.md).

## Soundtrack packages and states

Use **Soundtracks â†’ New soundtrack** to create one compatible subset. Choose
**Layer stack** or **Switch tracks**, define 1â€“12 named states, and fill each
state's pool with saved recordings. Save, then **Try in Mix lab â†’ New drive**.
The workbench selects a package first (specific or random), then one recording
per pool. Those choices stay fixed as states change. **Free mix** unlocks manual
experimentation. Packages persist locally and may be renamed, duplicated or deleted.

**Manage states** changes library labels/count independently of package states.
**Delete track** in Your library moves a recording to **Trash** and removes it
from package pools; Restore recovers the library entry. Source files stay on
disk. Empty pools must be repaired before package auditioning.

See [package contracts, tests and screenshots](../../docs/MUSIC_PACKAGES.md).

## Mix lab

Open **Mix lab** for the existing driving-arc and arrangement tools. Expand
**Earlier arrangement studies** to access the previous banks and endpoint pair.

**Reference arc R2:** use **R2 Â· All A**, **R2 Â· All B**, or **R2 Â· New drive**.
These load one of two options at each of six stages. New drive draws a new
combination, preventing an identical consecutive lineup; selections stay fixed
through stage changes, collision recovery and restart. Use Save setup to retain
a preferred combination. These are complete mix studies, not compatible stems.
Each stage's A/B files are matched separately for audition loudness.

1. **Load Focus / Breakthrough pair** loads the latest prepared endpoints.
2. Press **Play**. Change **Build to full** and **Qualification**, scrub **Clean
   streak**, or click a named stage. Disable **Advance while playing** to hold a
   state indefinitely. **Collision** returns to Focus for the recovery duration.
3. **Adaptive arrangements** selects one enabled take at a time. Missing stages
   hold the nearest lower available stage; the first added take wins stage ties.
   With only the endpoint pair, Focus holds until Breakthrough. This is intentional:
   intermediate states have not been approved/generated yet.
4. **Layer stack** adds enabled tracks cumulatively at their assigned entry
   stage. **Manual mix** plays all enabled tracks independently of streak time.
   Use On, Solo, Level and Master to compare combinations. Multiple Solo tracks
   may play together. Watch the output peak and lower levels if needed.
5. **Audition selected recording** replaces the mix with that concept and starts
   playback. **Add selected recording** adds it without replacing other tracks.
6. Playback position seeks the shared timeline. Loop in/out trims use seconds
   in each source. All buffers start on one Web Audio clock, but different loop
   lengths are not beat-synchronized. Raw generated recordings are not clean
   musical loops or separated instrument stems.
7. **Save setup** downloads JSON containing asset IDs, mix, trims and timeline.
   **Load setup** restores it. Local imported audio is not uploaded or embedded:
   reselect the files before loading a setup after a page reload.

Pause freezes playback, streak and recovery. Restart resets playback/streak.
The workbench models *qualifying streak time*, not vehicle speed smoothing or
canonical game simulation. Crossfades are immediate audition fades, not
bar-quantized production transitions. Browser background throttling can delay
control updates; use the foreground tab for evaluating transitions.

## Offline generation in Ubuntu / WSL2

The wrapper uses `BMT_MRT_VENV`, then `~/.venvs/bmt-magenta-rt2`, with a fallback
to the owner's existing `~/apps/magenta-realtime2/.venv`. CUDA visibility is
required. Python 3.12.3, Magenta 2.0.3, JAX/JAXlib 0.11.2 and the full working
dependency set are recorded in `requirements-lock.txt`. Do not upgrade silently.

```powershell
# Existing installation: validate without reinstalling or downloading assets.
wsl -d Ubuntu -- bash tools/music_generator/scripts/verify_mrt2.sh

# New environment only (Python 3.12 with venv must exist in Ubuntu):
wsl -d Ubuntu -- bash tools/music_generator/scripts/install_mrt2.sh
wsl -d Ubuntu -- bash tools/music_generator/scripts/init_models.sh

wsl -d Ubuntu -- bash tools/music_generator/scripts/smoke_test.sh
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py layers --config tools/music_generator/configs/grass.yaml --limit 1
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py concepts --config tools/music_generator/configs/concepts.yaml
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py layers --config tools/music_generator/configs/grass.yaml --names 00_focus 05_breakthrough --variants 1
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/prepare.py
```

Use `--dry-run` to review jobs without loading a model. Do not run GPU batches in
parallel. Every run gets a unique directory and atomically updated manifest;
failures are retained, completed jobs survive a later job failure, and old takes
are not overwritten. Output is restricted to `build/music`, outside Godot's
export root. Press Refresh to discover newly completed recordings.

The supplied CLI has no output or generation-seed flag. The adapter therefore
uses its installed public Python API and `Waveform.write` to an explicit path;
it loads the model once per batch. It never searches the home directory or
touches the CLI's shared output WAV.

R2 generation and review (local FFmpeg on PATH or at
`~/.local/share/bmt-music-tools/ffmpeg` required for review):

```powershell
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/generate.py layers --config tools/music_generator/configs/reference_arc_r2.yaml
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/review_iteration.py build/music/raw/reference_arc_r2/<run>/manifest.json
```

`variant_prompts` supplies one explicit musical direction per variant, placed
before the common stage brief. Review uses the existing adaptive-music skill's
`scripts/review_pack.py`, once per stage, preserving raw sources and exporting
constant-gain comparisons with a -2 dBTP ceiling. It does not repair source
clipping, enforce beats/harmony or imply approval.

**Prompt correction:** installed MusicCoCa accepts only 127 text tokens after
the start token. The original common-prefix prompts produced identical audio
for all concepts/endpoints. Distinguishing instructions now come first. The
manifest records full/effective prompts, truncation, style-conditioning tokens,
style mapper seed, actual parameters, versions, audio metrics and SHA-256.
Duplicate conditioning/PCM within a batch is rejected. The style mapper seed
is not a freely configurable generation RNG; upstream fixes its internal RNG.
Neither equal seeds nor family labels ensure harmonic compatibility.

`prepare.py` makes a **provisional** equal-length endpoint pair: one common gain
(maximum peak .5) and 10ms edge fades, PCM24 masters and source hashes. It does
not repair clipped source samples, time-stretch, establish BPM/key, separate
stems or claim compositional continuity. Raw files remain intact. The prepared
manifest leaves musical metadata explicitly unknown for listening/editing.

## Tests

```powershell
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/test_toolkit.py
# With the workbench server running and the existing developer Playwright env:
.tools/review/Scripts/python.exe tools/music_generator/test_browser.py
```

The browser suite uses installed Microsoft Edge, exercises real Web Audio,
and saves screenshots/results to `docs/evidence/music-toolkit`. It does not
certify timbre or human listening acceptance. See `docs/MUSIC_TOOLKIT.md` for
actual results and outstanding decisions. No game runtime integration is included.
