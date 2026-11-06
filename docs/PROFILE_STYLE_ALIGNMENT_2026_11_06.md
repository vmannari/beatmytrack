# Profile style alignment — 6 November 2026

The owner rejected the first profile redesign because it still felt like another game. This revision uses the existing Garage and Weekly Rivalry composition: a compact header, full-width vehicle photographs, shared dark panel treatment, condensed titles, quiet track rows, yellow secondary actions and a visible medal display. It retains the cars, recorded statistics, publications, drafts and achievement navigation from [the first implementation](PROFILE_REDESIGN_2026_11_06.md).

## Requirements and changes

- **PSA01 — match the existing game.** `game/ui/own_profile_page.gd` uses `MenuStyle.card`, the existing fonts and native Garage photographs. Car photographs fill their image area; the selected model uses the existing yellow outline and title. The tall statistics panel and separate car heading are removed from the visible layout. Totals sit alongside identity on wide layouts and reflow below it on smaller widths. Historical-source explanations remain in tooltips.
- **PSA02 — useful first view.** The five cars retain their kilometre and race counters. Card height responds to available page height. Actual-App checks require all five complete car cards, the first creation and three complete featured-medal controls to fit without scrolling at 1280×720 and 1280×672, the latter matching the owner's wider screenshot ratio. Small widths still reflow rather than clipping. The achievement count shares its section header; medals have no nested row backgrounds.
- **PSA03 — creations belong to the same menu.** Published/Draft tabs use quiet underlines. Track rows reuse biome glyphs and colours, condensed titles and right-aligned race counts. The small native route view preserves separate authored road sections; published route points remain closed loops. Missing summary geometry uses the existing neutral track icon. No new scenic artwork or track geometry is invented.
- **PSAQ01 — retain behaviour and review native output.** `game/tests/test_profile_redesign.gd` retains account fences, image provenance, counters, drafts, publication retry/filtering, saved history and in-profile achievement interactions. Added checks cover returning from portrait, both actual-App viewport proportions and exact separate road paths. No backend or persistence source is changed in this revision.

## Native comparison

The references were the existing [Weekly Rivalry](evidence/startup-shell-2026-11-04/rivalry-menu-seeded.png), [Daily card](evidence/daily-card-redesign-2026-11-03/native/gl_compatibility/earned-2.png) and [Garage lineup](evidence/hovercraft-sport-redesign-2026-10-29/app-gl_compatibility/garage-lineup.png). These are dated native references, not a claim about a newly captured device build.

- [Previous profile](evidence/profile-redesign-2026-11-06/captures/actual-app-profile.png).
- [Revised actual App](evidence/profile-style-alignment-2026-11-06/captures/gl_compatibility/actual-app-profile.png).
- [Revised wide aspect](evidence/profile-style-alignment-2026-11-06/captures/gl_compatibility/actual-app-profile-wide.png).
- [Published tracks and medals](evidence/profile-style-alignment-2026-11-06/captures/gl_compatibility/profile-1280x720.png).
- [German and long driver name](evidence/profile-style-alignment-2026-11-06/captures/gl_compatibility/profile-de.png).
- [Desktop Mobile actual App](evidence/profile-style-alignment-2026-11-06/captures/mobile/actual-app-profile.png).

The displayed names, counts and tracks are isolated fixtures. The actual-App guest view uses an isolated populated local save. Twelve captures per desktop renderer also cover 1720×900, 960×540, 400×720, drafts, scrolling, achievement collection and details. The screenshots are rendered controls and existing game assets, not generated mockups.

## Verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`. `APPDATA` was redirected to `build/profile-style-alignment/user`; `BMT_API_URL` was empty. Native captures used `BMT_PROFILE_CAPTURE=docs/evidence/profile-style-alignment-2026-11-06/captures/<renderer>` as an absolute path.

| Command / check | Outcome |
| --- | --- |
| `python scripts/run_no_crash_dialog.py -- <pinned-engine> --headless --path game --script res://tests/test_profile_redesign.gd` | 400 checks, zero failures, exit 0 |
| Same script with `--path game --rendering-method gl_compatibility` | 412 checks, zero failures, exit 0; 12 captures |
| Same script with `--path game --rendering-method mobile` | 412 checks, zero failures, exit 0; 12 captures; shutdown warning retained |
| `test_own_profile_page.gd`, pinned engine/headless | 23 checks, zero failures, exit 0 |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/own_profile_page.gd` | Completed, exit 0 |
| Task-only patch forward/reverse checks and scoped whitespace check | See checkpoint receipt |

Logs, task-start source copies, the task-only patch and its hash receipt are in [the evidence directory](evidence/profile-style-alignment-2026-11-06/). The checkpoint contains only this revision's two source/test files and its report/status changes; it excludes the earlier implementation and concurrent work. The main Git index was not written.

## Findings and limits

The first native layout still placed medal captions below the actual App's visible area. A later wider-aspect check exposed a small remaining overflow. Both failures are retained in `compatibility-fold-failure.log` and `compatibility-wide-fold-failure.log`; the final controls fit without weakening those assertions. A transient tall header after portrait switching was corrected by the single-line identity layout, with an explicit return-to-landscape check. Draft summaries carry road sections rather than ordinary route points; the revised preview handles those sections independently and uses a neutral icon when geometry is absent.

The engine still reports the existing Windows certificate-store diagnostic. Desktop Mobile reports one leaked ObjectDB instance at shutdown, as the preceding profile task also did; this work does not claim clean Mobile teardown. Backend historical coverage, the preceding broader achievement-test findings and rollout limits remain as documented in the first report. No new backend validation or deployment is claimed.

Owner appearance approval and physical tablet/phone touch and readability acceptance remain. No device query/test, APK/export, owner-save modification, owner-process restart, real authentication, live request, backend mutation or deployment was performed. This is a local presentation revision, not certification of AAA quality or device performance.
