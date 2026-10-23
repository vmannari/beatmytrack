# Track creator link - 2026-10-18

TCL01 makes the track-view creator name open the existing full track list with Creator search selected and the displayed name filled in. Unrelated favorites/biome/rating/history filters, legacy name fields, pending random/focus choices and the pinned detail version are cleared so they cannot hide that creator's other tracks. The retained close transition cancels pending selection work; normal paged discovery supplies results without downloading tracks or starting a race.

TCL02 renders the name as a yellow text link, with separate white “by” text, hover/press colors, keyboard focus, a full-name tooltip and a 48-unit touch target. Creator and rating remain vertically aligned. Original Share and title/favorite controls remain.

Changed files: `game/ui/track_browser.gd`, `game/tests/test_publication_share.gd`, this note and `DEVELOPMENT_STATUS.md`. The existing real-app sharing suite now also taps the creator name through viewport input, verifies one creator-only server query, checks results from two biomes, excludes a different creator whose track title contains the searched name, and verifies preserved favorites and no race startup. Existing sharing and navigation checks remain.

Actual validation uses pinned Godot 4.7.2 and process-local `APPDATA` directories under `build/track-creator-link-{headless,compatibility,mobile,list}/appdata`. Each command follows directory creation and invokes `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with normal host certificate-store access:

- `-Action TestScript -ScriptPath res://tests/test_publication_share.gd -TestArgument --evidence=res://../docs/evidence/track-creator-link-2026-10-18/headless` - 45 checks, zero failures.
- The same suite with `-Graphical -RenderingMethod gl_compatibility` and evidence `gl_compatibility` - 45 checks, zero failures.
- The same suite with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan` and evidence `mobile` - 45 checks, zero failures on the desktop Mobile renderer.
- `-Action TestScript -ScriptPath res://tests/test_free_race_list.gd -TestArgument --evidence-root=res://../docs/evidence/track-creator-link-2026-10-18/list-headless` - 233 checks, zero failures across 960x540, 1280x720 and 1720x900.
- `git diff --check -- game/ui/track_browser.gd game/tests/test_publication_share.gd` - passes.
- `git apply --reverse --check --ignore-space-change -- docs/evidence/track-creator-link-2026-10-18/task-only.patch` - validates the source-only checkpoint against the working files, allowing their existing line endings.

Native views: [colored creator link](evidence/track-creator-link-2026-10-18/gl_compatibility/shared-free-race-detail.png), [creator results after touch](evidence/track-creator-link-2026-10-18/gl_compatibility/creator-track-results.png), [desktop Mobile link](evidence/track-creator-link-2026-10-18/mobile/shared-free-race-detail.png) and [desktop Mobile results](evidence/track-creator-link-2026-10-18/mobile/creator-track-results.png). Logs are saved under [logs](evidence/track-creator-link-2026-10-18/logs); saved original sources, [hashes](evidence/track-creator-link-2026-10-18/source-hashes.json) and [task-only.patch](evidence/track-creator-link-2026-10-18/task-only.patch) preserve the scoped review checkpoint.

This uses the existing creator-name search semantics. No account-ID search contract or backend change is introduced. The previously documented graphical list score-fixture failure was not rerun or changed. Owner appearance/workflow acceptance remains. No phone attachment check/device test, APK/export/install or deployment was performed.
