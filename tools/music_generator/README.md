# Offline music workbench

Run from the Windows repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/music_generator/launch.ps1
```

Open <http://127.0.0.1:18765>. Windows Python 3.10+ is sufficient for the workbench;
it uses standard-library HTTP and browser Web Audio, with no npm/CDN dependency.
The server listens only on loopback and exposes its UI and `build/music` audio.
Port 8765 is reserved on this machine; `-Port` can select another port.
Stop the server with Ctrl+C. The VS Code task **Music: Open workbench** does the same.

## Listening

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
