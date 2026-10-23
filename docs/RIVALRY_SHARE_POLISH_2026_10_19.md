# Rivalry sharing presentation refinement — 2026-10-19

The owner rejected the readable but generic copied-results popup as insufficiently polished. RSP01 replaces that presentation with a dedicated championship card: scenic event identity and the player's actual event car on the left, a clear position/points/victories summary and five aligned track rows on the right. A quiet green copied status and a compact Done action finish the card. The giant success symbol, plain-text dump and unused space are removed from this flow.

The hero uses the existing illustrated Winter artwork, bundled fonts/icons, real country/name and the retained event-car renderer with local paint, fitted parts and condition. It uses that renderer's existing static studio lighting, transparency and camera fitting. Track rows reuse the original scenic route thumbnail and actual pinned names, biomes, positions, times and points. Gold achievement treatment follows the real award tier; Perfect Week requires all five outright victories. No new generated or externally sourced artwork is introduced.

RSP02 preserves readable spacing at the regular viewport-bounded 1120×620 preferred size and the 820×560 minimum card size. All five rows fit without initial scrolling in the verified layouts. Short layouts reduce summary type and row padding while preserving the full dismissal targets. Long names use bounded ellipsis with their full name available on the row; the copied payload retains every character. Footer controls sit outside the results viewport. Focused/pressed Done text stays dark on yellow.

RSP03 retains the original text-sharing contract: `finale_share_text()` goes unchanged to the clipboard or native adapter, and the native path opens no desktop confirmation. Busy/cached/active/account-and-car guards, actual scores, local settings, modal dismissal, scrim cleanup and focus restoration remain. The existing owned-dialog lifecycle is inherited; unrelated notices keep their existing presentation. The prior Rivalry-specific plain-text notice classifier is removed because this flow now has its own view.

Changed source: `game/core/app.gd`, `game/ui/fault_dialog.gd`, new `game/ui/rivalry_share_dialog.gd` and `game/ui/rivalry_share.gdshader`, and `game/tests/test_rivalry_share.gd`. This note and `DEVELOPMENT_STATUS.md` record the work. The [task-only.patch](evidence/rivalry-share-polish-2026-10-19/task-only.patch), saved original/final files and [source hashes](evidence/rivalry-share-polish-2026-10-19/source-hashes.json) isolate this refinement from the existing worktree changes. Concurrent publication-prompt edits in `app.gd` are preserved and excluded from the patch: its `checkpoint-base` keeps the current surrounding source and restores only the captured original Rivalry share function. The initial unmodified captures remain under `before`.

R01 actual verification uses pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, with isolated `APPDATA` directories under `build/rivalry-share-polish-*` and unique fixture saves. Fixtures disable the backend URL; native sharing uses a recording adapter without sending anything. Commands below use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with normal Windows certificate/rendering access:

- `-Action TestScript -ScriptPath res://tests/test_rivalry_share.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence=res://../docs/evidence/rivalry-share-polish-2026-10-19/checked-gl_compatibility` — 312 checks, zero failures; [log](evidence/rivalry-share-polish-2026-10-19/logs/checked-gl_compatibility.log).
- The same test with `-RenderingMethod mobile -RenderingDriver vulkan` and evidence directory `checked-mobile` — 312 checks, zero failures on the desktop Mobile renderer; [log](evidence/rivalry-share-polish-2026-10-19/logs/checked-mobile.log).
- `-Action TestScript -ScriptPath res://tests/test_rivalry_share.gd` — 295 checks, zero failures; [log](evidence/rivalry-share-polish-2026-10-19/logs/checked-test_rivalry_share.log).
- `-Action TestScript -ScriptPath res://tests/test_fault_dialog.gd` — 95 checks, zero failures; [log](evidence/rivalry-share-polish-2026-10-19/logs/checked-test_fault_dialog.log).
- `-Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd` — 64 headless checks, zero failures; [log](evidence/rivalry-share-polish-2026-10-19/logs/checked-test_rivalry_awards.log).
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` — 903 scripts, zero failures; [log](evidence/rivalry-share-polish-2026-10-19/logs/checked-test_script_parse.log).
- `git diff --check -- game/core/app.gd game/ui/fault_dialog.gd game/tests/test_rivalry_share.gd` — passes, with the existing CRLF normalization warning.

The focused test exercises unranked and Perfect Week snapshots at 1848×937, 1280×720, 960×540 and 1600×720, plus the minimum-size dialog. It checks every row's exact times/points/names, full row visibility, nonoverlapping columns, hierarchy/control clearance, actual car/paint, clipboard/native equality, state guards, dismissal/focus and unchanged settings/scores. The presentation assertions supersede the old plain-message-body assertions and strengthen the requirement from scroll reachability to five immediately visible rows.

Initial corrections remain recorded: [preview.log](evidence/rivalry-share-polish-2026-10-19/logs/preview.log) reproduces eight final-row fit failures in the first design. The retained headless row diagnostic shows the smaller actual dialog surface; the compact layout then exposed eight insufficient-heading-gap failures before row padding and section spacing were corrected. All original invariant checks remain; none were removed to obtain the final passes. The intermediate renders/logs are separate from the final `checked-*` evidence.

G01 inspected native views:

- [Previous generic confirmation](evidence/rivalry-share-2026-10-19/gl_compatibility/share-unranked-top-1848x937.png).
- [Refined unranked week, Compatibility](evidence/rivalry-share-polish-2026-10-19/checked-gl_compatibility/share-unranked-1848x937.png).
- [Perfect Week at 960×540, Compatibility](evidence/rivalry-share-polish-2026-10-19/checked-gl_compatibility/share-perfect-960x540.png).
- [Perfect Week at 960×540, desktop Mobile](evidence/rivalry-share-polish-2026-10-19/checked-mobile/share-perfect-960x540.png).
- [Minimum-size card](evidence/rivalry-share-polish-2026-10-19/checked-gl_compatibility/share-compact-820x560.png).

Q01: owner appearance acceptance remains. These are desktop window/renderer checks; no phone attachment check or physical-device test, APK/export/install, backend/account mutation, external message or deployment was performed. Native sharing still sends the existing text summary.
