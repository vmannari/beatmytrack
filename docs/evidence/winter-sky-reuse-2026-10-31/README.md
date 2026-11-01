# Winter sky reuse component probe — 31 October 2026

The synthetic renderer probe in `profile.gd` compares a newly constructed Winter `Sky` with a previously rendered, identical sky on a stationary metallic sphere. It alternates mode order for 12 stages and checks the settled framebuffer bytes against the same reference. It is not a game-level, cold-shader, phone, thermal or FPS measurement. The pinned desktop engine used Compatibility on an RTX 3090 at 640 × 360 with VSync disabled; driver caches were not cleared.

The retained `synthetic-report.json` records all stage timings from the second run. First-frame-post-assignment medians were 4.278 ms for new skies and 0.560 ms for reuse. Medians of the highest reported GPU time within each 12-frame window were 2.363 ms and 0.641 ms respectively; renderer timing is delayed and its precise frame association is not established. All 24 settled framebuffer comparisons were byte-exact. The initial run also produced 24 exact comparisons, with first-interval medians 3.559 and 0.594 ms; its complete timing rows were not saved. The second process exited zero but reported two GL texture leak warnings of 87,380 bytes each at shutdown during fixture cleanup. The recorded runner placed `quit()` on the same line as the intended 20-frame cleanup loop, so only its first iteration may have completed; the saved reproducible script corrects that control-flow issue and has not yet been rerun. The actual Winter gameplay test described below did not report these warnings. Do not interpret the component result as proof of memory release or normal race-load speedup.

The real Compatibility Winter environment suite separately passed 109 checks with no failures using the changed production code. It measured 27,747 pixels affected by sky reflections, 46,296 by seam reflections, and zero unstable restored pixels. Its output went to `build/winter-sky-audit/winter-compatibility`; capture outputs are not committed evidence.

The headless `res://tests/test_winter_sky_reuse.gd` passed 13 checks, covering shared editor/race use, independent biome changes, cache trim and recreation, weak-reference teardown, actual App accounting, ordinary retained-budget trimming and forced pressure. The shipping-source parse passed 504 scripts. Windows emitted a root-certificate-store read error in these isolated offline processes.

To repeat the synthetic probe from the repository root in PowerShell with a private profile:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/winter-sky-audit/user'
$env:BMT_API_URL = ''
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --audio-driver Dummy --script res://../docs/evidence/winter-sky-reuse-2026-10-31/profile.gd
```

The probe writes `build/winter-sky-audit/report.json`; create that directory first. It intentionally constructs its own reference skies to isolate the resource-reuse mechanism. Actual scene loading, mobile rendering, pressure timing, and memory consumption remain separate measurements.


## Corrected cleanup rerun

The saved script was corrected to wait all 20 cleanup frames and clear the new production static sky cache before quitting. The corrected isolated Compatibility process exited zero without GL texture-leak warnings. It still reported the offline Windows certificate-store error. Across 12 alternating stages per mode, settled image bytes remained exact; median first post-assignment interval was 5.223 ms for newly created skies and 0.380 ms for the shared sky. The medians of the peak reported GPU time in each 12-frame window were 4.339 ms and 1.135 ms; renderer measurements are delayed and their exact frame association remains uncertain. The probe is a warm-shader synthetic component measurement, not a full race, Android, FPS or memory acceptance result. Raw stages and console output are in `corrected-report.json` and `corrected-output.log`.
