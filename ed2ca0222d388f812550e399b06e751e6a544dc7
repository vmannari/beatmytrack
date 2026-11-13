# Completion cards fit without ordinary scrolling

RCF01: Reduce the standings charts' minimum height from 130 to 104 and the standings stack's gaps from 8 to 6. This lowers the content minimum from 539 to 505 logical units. Extra available height still grows the charts. All three recommendation cards can fit above the fixed footer in the normal landscape layout, including a 520-unit content slot with larger margins. RCF02: Retain the square 56-unit Home button and its existing dynamic alignment to the content edge with or without the scrollbar.

Runtime file: `game/ui/race_complete.gd`. Existing scrolling, footer, Home behavior and all concurrent source edits remain. No new regression suite or fixture assertions were added.

Actual commands, from the repository root:

```powershell
python build/results-fit-2026-11-03/run_capture.py
python build/results-fit-2026-11-03/run_capture.py --before
python build/results-fit-2026-11-03/run_capture.py --capture
git apply --reverse --check docs/evidence/results-fit-2026-11-03/task.patch
git diff --check -- game/ui/race_complete.gd
```

The retained runner is `docs/evidence/results-fit-2026-11-03/run_capture.py`. It instruments the existing footer-fit fixture with the actual MarginContainer host, populated captions, completion reward and explicitly offline chart samples. Storage is isolated, service origin empty, and pinned Godot 4.7.2 runs through the crash-dialog suppression wrapper.

The first ordinary-margin headless run passes 46/0 and already fits. With identical larger margins, the task-start source control passes its retained 46/0 checks but shows scrollbars in all five samples: its 539-unit content exceeds the normal 520-unit slot. Final native Compatibility passes **51 checks, 0 failures**, including five captures. Four normal samples now have no scrollbar; one deliberately constrained 424-unit slot keeps fallback scrolling. Returning from that constrained slot to normal removes the scrollbar and restores Home to the expanded card edge. Every logged Home/card right edge is equal and Home stays 56 by 56. Canvas-items stretching means window and logical canvas sizes differ.

[Normal layout with all three cards visible](evidence/results-fit-2026-11-03/footer-1280x720.png). The native fixture has no race backdrop or online population. Existing certificate-store warnings remain; all these runs exit successfully. The source-only task patch passes reverse application checking, and whitespace checking passes.

Reload and owner appearance/touch acceptance remain. No physical-device query/test, APK, backend/live access, deployment, owner-save/process change or main-index write was performed.
