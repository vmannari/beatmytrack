# Garage Workshop restored — 2026-10-25

GWR01 restores this conversation's requested navigation after a later reference-styling pass replaced Workshop with separate Appearance, Wash and Parts rail buttons. The existing Workshop tabs had been explicitly hidden. Two runtime lines in `game/ui/garage_page.gd` restore the five-entry rail and visible Appearance / Parts / Wash tabs, with remembered Workshop selection.

GWR02 retains the newer workbench styling and absent customisation footer. Record player, Trophy wall and News remain independent destinations. Preview/equip, account, cleanliness and local-save code is unchanged. This supersedes only the direct task navigation portion of GCR01. The top AGENTS.md override records that precedence so future styling passes preserve Workshop.

The sidebar suite now targets Wash and Parts through their tabs and checks exactly five rail destinations, absent individual task rail buttons, visible tabs and touch/window bounds. Its existing full-height News, retained viewport/car, fixed rail, pointer activation and empty customisation footer checks remain. The carousel suite expects visible Workshop tabs and aligns the whole car column with the workbench; all ownership, preview, cancellation and photo bounds remain.

Native Compatibility and desktop Mobile navigation each pass 475 checks across 960×540, 1280×720 and 1600×720. Existing headless customisation carousel passes 246 checks. The initial desktop Mobile attempt encountered a concurrent Garage edit referencing a new `garage_part_photos.gd` before that file existed; this unrelated work was preserved. After the file appeared, the desktop Mobile rerun passed. Exact commands and results are under [evidence](evidence/garage-workshop-restored-2026-10-25/report.json), with per-run command.json and console.log.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-workshop-restored-2026-10-25/run.ps1 -Test test_garage_sidebar -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-workshop-restored-2026-10-25/run.ps1 -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-workshop-restored-2026-10-25/run.ps1 -Test test_garage_sidebar -Mode mobile
git diff --check -- AGENTS.md game/ui/garage_page.gd game/tests/test_garage_sidebar.gd game/tests/test_customisation_carousel.gd
git apply --stat docs/evidence/garage-workshop-restored-2026-10-25/task-only.patch
```

Runs use pinned Godot 4.7.2 through scripts/dev.ps1, workspace-only disposable APPDATA and offline test records, with host certificate-store access. The [task-only patch](evidence/garage-workshop-restored-2026-10-25/task-only.patch) isolates the two runtime changes from later concurrent source changes; it does not stage or commit unrelated work.

Review [Appearance at 960×540](evidence/garage-workshop-restored-2026-10-25/test_garage_sidebar-gl_compatibility/customise-960.png), [Parts](evidence/garage-workshop-restored-2026-10-25/test_garage_sidebar-gl_compatibility/tuning-1280.png), [Wash](evidence/garage-workshop-restored-2026-10-25/test_garage_sidebar-gl_compatibility/care-1280.png), [record player](evidence/garage-workshop-restored-2026-10-25/test_garage_sidebar-gl_compatibility/records-1280.png) and [News](evidence/garage-workshop-restored-2026-10-25/test_garage_sidebar-gl_compatibility/news-1280.png).

Client reload and owner appearance/touch acceptance remain. No phone/tablet attachment check or physical-device test was performed. No APK, deployment, purchase, live mutation or owner-process restart.
