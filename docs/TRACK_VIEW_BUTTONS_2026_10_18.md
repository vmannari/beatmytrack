# Track view buttons — 2026-10-18

TVB01 matches Free Race's Share icon to the neighboring close button: the same 48-unit minimum, translucent navy surface and existing hover/press/focus theme. TVB02 moves the favorite star immediately after the track title with a 12-unit gap and vertical centering. Short titles keep the star close; long titles clip within the available title area. Sharing, saved favorites, selection and navigation retain their existing callbacks.

Changed source: `game/ui/track_browser.gd`. The existing placement assertion in `game/tests/test_free_race_list.gd` now checks the owner's new title/star arrangement, superseding the old requirement to put the star below X. This note and `DEVELOPMENT_STATUS.md` record the result. The source-only review checkpoint is [task-only.patch](evidence/track-view-buttons-2026-10-18/task-only.patch), with saved original sources and [hashes](evidence/track-view-buttons-2026-10-18/source-hashes.json).

Actual checks use the pinned Godot 4.7.2 through `scripts/dev.ps1`. Each run sets `APPDATA` to its own directory under `build/track-view-buttons-*`, and creates that directory before invocation. Commands below use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action TestScript -ScriptPath res://tests/test_free_race_list.gd -TestArgument --evidence-root=res://../docs/evidence/track-view-buttons-2026-10-18/final-headless` — 233 checks, zero failures; 960×540, 1280×720 and 1720×900.
- `-Action TestScript -ScriptPath res://tests/test_publication_share.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence=res://../docs/evidence/track-view-buttons-2026-10-18/final-gl_compatibility` — 39 checks, zero failures.
- The same sharing test with `-RenderingMethod mobile -RenderingDriver vulkan` and `--evidence=res://../docs/evidence/track-view-buttons-2026-10-18/final-mobile` — 39 checks, zero failures on the desktop Mobile renderer.
- `-Action CheckScript -ScriptPath res://ui/track_browser.gd` — passes.
- `git diff --check -- game/ui/track_browser.gd game/tests/test_free_race_list.gd` — passes.

The graphical Free Race list run (`-Graphical -RenderingMethod gl_compatibility`, evidence `final-list-gl_compatibility`) reaches the correct title/star arrangement at 960×540 and 1280×720, then fails its populated-score fixture: “three scores: all three score actions remain available”, followed by a null `get_global_rect` at line 115. This same pre-existing graphical fixture failure and original-source reproduction are recorded in [the preceding sharing task](PUBLICATION_NEWS_SHARE_2026_10_18.md). This suite is not claimed passing; its score assertions remain intact.

Initial direct PowerShell launches were blocked by execution policy. Subsequent restricted engine launches could not access user logs or the Windows root certificate store; final isolated runs used normal host access. The first preview exposed a zero-size title measurement before the label entered the scene tree; measuring the actual display font fixes the title width and reserved row height. Initial captures are retained separately from the final views.

Inspected native screenshots:

- [Final Share and title/star, Compatibility](evidence/track-view-buttons-2026-10-18/final-gl_compatibility/shared-free-race-detail.png)
- [Final Share and title/star, desktop Mobile](evidence/track-view-buttons-2026-10-18/final-mobile/shared-free-race-detail.png)
- [Small window, saved favorite](evidence/track-view-buttons-2026-10-18/final-list-gl_compatibility/detail-960x540.png)

Owner appearance acceptance remains. No phone attachment check or device test, APK/export/install, backend mutation or deployment was performed.
