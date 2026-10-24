# Challenge results redesign ? 24 October 2026

CRV01 / CRV02 / CRV03 / R01 / G01 / Q01.

The challenge result page now uses the shared `MenuStyle.time_text` for the completed run, saved best, target/leader and every standing. The owner example `106.350` is displayed as `01:46.350`. Signed differences remain seconds with an explicit seconds label.

The old full-width strip and sparse table are replaced by a scenic circuit card, a personal result panel with position and verification state, and a separate standings panel with aligned time/gap columns. The circuit outline and start/finish marker use the actual selected route. Existing original biome artwork and project fonts are reused; no new assets, dependencies or generated art were introduced.

Server `outcome.ms` supplies **this run** only when verified and counted. The saved challenge best is shown separately when slower finishes differ; pending/rejected results retain only the official best and explain their status. Multi-track runs identify their track separately from the aggregate. Rank/tries from JSON numbers display as integers. Targets, standings, ownership, rewards, tries, rematches and cancellation retain their existing server authority.

The results component reflows into a vertical scroll at narrow widths. Short landscape and the full app menu prioritize the personal result, reduce scenic height and retain the action bar. Standings have their own scrolling region, including the last of twenty drivers. Retry clearly says when tries are exhausted; Back becomes the primary available action. An empty selected snapshot retains header navigation. The ordinary challenge browser keeps its current layout and concurrent multi-track work.

Changed runtime files: `game/ui/challenges_page.gd` delegates result presentation; `game/ui/challenge_result_view.gd` owns the result layout. `game/tests/test_challenge_result_view.gd` exercises native rendering, actual input, real app composition and service snapshots. The evidence directory holds the runner, logs, captures, source hashes, task-start page snapshot and a scoped reversible Git patch.

## Actual validation

Use the pinned Godot `4.7.2.stable.official.ed1daf0bf`. The normal development entry point was tried first. Initial process policy/default-userdata issues were corrected using a process-local policy and workspace APPDATA. As in the existing Store evidence runner, the strict development runner stops on the sandbox certificate-store diagnostic; the retained runner verifies the same pinned binary and records that diagnostic without suppressing it or disabling TLS checks.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/challenge-results-redesign-2026-10-24/run_validation.ps1 -Test test_challenge_result_view -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/challenge-results-redesign-2026-10-24/run_validation.ps1 -Test test_challenge_result_view -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/challenge-results-redesign-2026-10-24/run_validation.ps1 -Test test_challenge_result_view -Mode mobile
```

| Native check | Actual result |
|---|---|
| Focused headless | 293 checks, 0 failures |
| Focused Compatibility | 303 checks, 0 failures |
| Focused desktop Mobile/Vulkan | 303 checks, 0 failures |
| Existing challenges headless | 216 checks, 0 failures |
| Existing challenges Compatibility with captures | 255 checks, 0 failures |
| Existing series | 30 checks, 0 failures |
| App | 141 checks, 0 failures |
| Complete script parser | 1070 scripts, 0 failures |
| Scoped patch reverse check | Passed |

All other actual commands are recorded in [report.json](evidence/challenge-results-redesign-2026-10-24/report.json). Captures include 1280?720, 844?390 and 390?844 layouts, one/twenty drivers, a beaten target, rejected result, series, and the real app menu. The full existing challenge suite was also run headless and with native Compatibility captures at 1280?720, 960?540, 1600?720 and 1440?900. Capture data is isolated and is not a live account.

## Corrections retained

The first native review exposed a gap label wrapping one character per line; a bounded label width and regression assertion fix it. A new initial ?desktop fits? assertion incorrectly included the short 960?540 viewport; the final contract requires the ordinary tall desktop view to fit and permits vertical scrolling in short layouts while retaining visible personal time/actions. Existing assertions were not removed. The full app review then prompted the compact presentation and an explicit real-app fit assertion.

A copied runner initially missed its renamed PowerShell splat and launched the isolated default scene; only that spawned command was stopped, then the splat was corrected. The first full-suite capture used a resource URI where its helper requires an absolute Windows path; that run was stopped, its error log is retained as `initial-capture-path-error.log`, and the corrected run passed all 255 checks. Fixture interface audio was disabled after native shutdown reported live WAV playbacks. Final focused runs do not report those resource leaks.

## Remaining acceptance

Reload the local client and review the result appearance with real challenges, including a slower finish, exhausted tries and a series. Phone/tablet attachment was not checked and no physical-device test was performed. Desktop Mobile means Vulkan on the PC, not Android certification. Narrow/short content intentionally scrolls, with actions fixed below it. No APK/export/install, live account/backend mutation, external share, purchase or deployment was performed. Owner processes and concurrent changes were preserved.
