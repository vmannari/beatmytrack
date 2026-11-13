# Results Home button alignment

RH01: Home now stays 56 × 56 logical units, vertically centered in the completion header. RH02: Its right edge follows the standings card below, including the 24-unit scrollbar lane when visible. The existing palette, icon and Home action remain. Runtime change: `game/ui/race_complete.gd`; concurrent completion scrolling/footer work is preserved.

Actual commands, run from the repository root:

```powershell
python build/results-home-2026-11-02/run_capture.py
git apply --reverse --check docs/evidence/results-home-2026-11-02/task.patch
git diff --check -- game/ui/race_complete.gd
```

The capture runner is retained at `docs/evidence/results-home-2026-11-02/run_capture.py`. It runs the existing footer-fit fixture with temporary capture/geometry instrumentation, isolated profile storage, no service origin, pinned Godot 4.7.2 and the crash-dialog suppression wrapper. No new regression suite was added.

Native Compatibility: **61 checks, 0 failures**, across six window sizes. Logged Home sizes are exactly 56 × 56; Home/card right edges match in all twelve samples, including five forced visible-scrollbar samples and the tall layout where the scrollbar disappears. Twelve top-of-page captures and six existing footer captures are retained. [Square button aligned above the card](evidence/results-home-2026-11-02/scrollbar-1280x720.png). The isolated fixture has no race backdrop or online population. Canvas-items stretching means window dimensions can differ from the logical canvas.

The initial capture probe incorrectly indexed an internal scrollbar child and timed out; the corrected probe and successful native logs are retained, with the initial finding recorded separately. The existing root-certificate-store warning remains. Task-only patch reverse validation and whitespace checks pass; the patch is relative to task-start working sources, preserving earlier edits.

Reload and owner appearance/touch acceptance remain. No physical-device query/test, APK, backend/live access, deployment, owner-save/process change or main-index write was performed.
