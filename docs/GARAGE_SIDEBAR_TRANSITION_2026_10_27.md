# Garage sidebar remains visible during submenu changes

GST01–GST02 / R01 / Q01, 2026-10-27.

The sidebar previously joined every outgoing menu animation: it moved left offscreen, its replacement waited for the outgoing controls, and all five buttons were rebuilt. Switching Appearance, Parts, Wash or the other Garage sections therefore briefly removed the navigation.

`game/ui/garage_page.gd` now retains the sidebar and its five native buttons. It places them directly in their layout slot and refreshes their selected styles and sound cues. Content panels retain their existing 0.32-second transitions. The buttons remain available for another selection during those transitions, and keyboard focus survives a submenu change.

`game/tests/test_garage_sidebar.gd` now samples nine points through each transition at 960×540, 1280×720 and 1600×720. It checks the same button instances, exact rectangles, visibility and input state, then exercises a real touch selection while a prior transition is paused partway through. Existing layout, car/viewport retention, wash shortcut and save assertions remain.

Actual results with pinned Godot `4.7.2.stable.official.ed1daf0bf`:

| Check | Outcome |
| --- | --- |
| Task-start runtime with strengthened regression | 4,456 checks, 2,151 failures |
| Fixed headless sidebar suite | 4,456 checks, zero failures |
| Fixed desktop Compatibility | 4,494 checks, zero failures |
| Fixed desktop Mobile/Vulkan | 4,494 checks, zero failures |
| Existing App regression | 141 checks, zero failures |
| Project script compilation | 1,338 scripts, zero failures |

Both rendered runs save 38 real screenshots, including intermediate transition frames. Reviewed examples: [Compatibility during Record player entry](evidence/garage-sidebar-transition-2026-10-27/final-compatibility/motion-records-1280-3.png), [Compatibility Wash transition](evidence/garage-sidebar-transition-2026-10-27/final-compatibility/motion-care-1280-3.png), and [Mobile interrupted News entry](evidence/garage-sidebar-transition-2026-10-27/final-mobile/motion-interrupted-news-1280-3.png).

Reproduce using `python docs/evidence/garage-sidebar-transition-2026-10-27/run_checks.py LABEL SCRIPT MODE`, where SCRIPT is `test_garage_sidebar.gd`, `test_app.gd` or `test_script_parse.gd`, and MODE is `headless`, `gl_compatibility` or `mobile`. Exact commands, isolated offline environments, source hashes, screenshots and logs are in [report.json](evidence/garage-sidebar-transition-2026-10-27/report.json). The dedicated harness invokes the pinned engine directly to avoid the development wrapper regenerating unrelated build identity files.

The raw logs retain the existing sandbox root-certificate-store error; offline test assertions and script compilation pass. The first patch check encountered Windows line endings; the LF patch passes plain `git apply --check` against a normalized disposable copy of the exact task-start sources. [task.patch](evidence/garage-sidebar-transition-2026-10-27/task.patch) contains only this task's runtime and test changes; concurrent changes are preserved and excluded.

Reload the client to use the fix. Owner visual/input acceptance remains. No physical-device attachment check or test, APK, owner-save change, live-service mutation, deployment, owner-process restart, staging, commit or merge was performed.
