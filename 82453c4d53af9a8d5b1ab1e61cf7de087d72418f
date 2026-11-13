# Race mode order (2026-10-29)

RMO01: The shared Race rail now reads Weekly Rivalry, Track of the Day, Free Race, Challenges, from top to bottom. RMO02: Page transition direction follows that same order.

Two runtime lines change: the rail entries in `game/ui/race_mode_rail.gd` and `RACE_MODE_PAGES` in `game/core/app.gd`. Existing icons, mode IDs and actions remain. No backend change is needed for this reorder.

R01: The unchanged `test_race_mode_input.gd` passed **62 checks, zero failures**, including five captures at 1280×720 and 960×540. It exercises mouse/touch press and release, interrupted arrival, rapid selection, retained Rivalry controls and account fencing. Source scope checks verify the exact requested order, agreement with page order, and one changed line in each runtime source. No new test was added for this small reorder.

Command run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/race-mode-order-2026-10-29/run.ps1 -Renderer gl_compatibility
git apply --reverse --check docs/evidence/race-mode-order-2026-10-29/source.patch
```

The runner uses the pinned `scripts/dev.ps1` entry point, an empty API override and isolated save folders. Generated build metadata is restored only while it still belongs to that run. The first launch was refused by process execution policy; the command above permits only its child process. A sandboxed attempt then failed Windows certificate-store access before App startup. The identical offline native test passed with normal local access. Both native logs are retained; the outer shell also emitted a profile policy warning before the successful command. No system execution-policy setting was changed.

Q01: The [two-source patch](evidence/race-mode-order-2026-10-29/source.patch) passes actual working-tree reverse check and exact forward/reverse comparisons in an isolated folder. [Report and hashes](evidence/race-mode-order-2026-10-29/report.json). [Updated menu](evidence/race-mode-order-2026-10-29/after/gl_compatibility/free-race-1280x720.png); the empty track library is the offline test fixture.

Reload/rebuild and owner/device acceptance remain. No device query/test, APK, live API write/deployment, owner-save mutation, owner-process restart or main-index staging/commit/merge. Existing concurrent work is preserved.
