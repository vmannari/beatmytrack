# Garage navigation performance observations (2026-10-30)

An isolated actual-App graphical profile measures car preview switches and retained Garage returns. The desktop Compatibility run after deferring triangle-picking preparation passes its target-car and retained-page checks. Individual switch callbacks still take tens to hundreds of milliseconds; the first observed Pickup draw took seconds. There is no claim here that cold rendering or every Garage return has been fixed.

| Desktop observation | Callback | First draw |
| --- | ---: | ---: |
| Baseline Pickup, first switch | 50 ms | 9,183 ms |
| Baseline second pass, six cars | 40–263 ms | 50–275 ms |
| After lazy picking, second pass, six cars | 32–201 ms | 42–216 ms |
| Unchanged-selection return from Tracks, Settings or Biome, both runs | 2.5–6.5 ms | 16–25 ms |
| After lazy picking, return after selecting Kart, Forklift or Compact in the header | 147–221 ms | 258–310 ms |

These are sequential single desktop observations, not a controlled speedup or phone frame-rate result: driver and OS caches, shader compilation and concurrent GPU work affect them. The first and second runs used the same isolated APPDATA location, but new isolated records; the first process warmed caches for the second. Each row records ten or more actual draw intervals and checks that the requested car becomes ready. The return test also checks the same Garage page remains retained. The first draw is an observation after the frame-post-draw signal, not a direct measurement of physical presentation or touch-to-photon latency. The unchanged-return test does not reproduce all possible page, memory-pressure, appearance-change or cold-start conditions. Selecting another car in the header exposes a real additional return cost, but has no before-change comparison in this profile.

Pinned Godot 4.7.2 Compatibility, Windows, RTX 3090, 1280×720; sandbox runs printed the Windows root-certificate-store error. Both full runs and the separate changed-selection run exited zero with no benchmark assertion failures. The run output was observed in the process output but was not saved as a separate console log; the complete timing rows are retained in [baseline.json](evidence/garage-navigation-performance-2026-10-30/baseline.json), [final.json](evidence/garage-navigation-performance-2026-10-30/final.json) and [changed-selection.json](evidence/garage-navigation-performance-2026-10-30/changed-selection.json). The first two runs used the same earlier version of the benchmark; the current [benchmark](../game/tests/profile_garage_navigation.gd) additionally tests header selection before return and offers `--changed-selection-only`.

The [baseline showroom source](evidence/garage-navigation-performance-2026-10-30/car_showroom-before.gd) and [measured lazy-picking source](evidence/garage-navigation-performance-2026-10-30/car_showroom-measured.gd) have SHA-256 `dda37a4ee073548ae126063a4bd03ef4cdec394411e9924898b3aed121e3d600` and `33ceec8f243be8d079c2e404e694bd722b240016ac8bd03211da4aca3be1bc66`, respectively. The baseline hash list was collected while the first process was running, before the showroom change; the author confirmed the showroom was unchanged at launch. The final run's [start](evidence/garage-navigation-performance-2026-10-30/garage-nav-profile-hashes-after-start.json) and [end](evidence/garage-navigation-performance-2026-10-30/garage-nav-profile-hashes-after-end.json) source hashes match for the listed files. These are scoped hashes rather than a whole-workspace snapshot.

From the repository root, run in PowerShell with an isolated profile and the noninteractive crash-dialog wrapper:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/garage-nav-profile-user'
$env:BMT_API_URL = ''
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script res://tests/profile_garage_navigation.gd -- --output=res://../build/garage-nav-profile/run.json
```

Add `--changed-selection-only` after `--` to run only the three header-selection returns. Profile data and its local records remain isolated from the owner's save. No device test or deployment was performed. The recorded cache-sensitive observations do not establish physical-device acceptance or remove the previously documented native shader-link stalls.
