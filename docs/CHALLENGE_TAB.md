# Race Challenges tab — 2026-10-10

The owner authorized the benchmark-led presentation pass, narrowed to the Challenges tab within Race. The inbox/detail composition now emphasizes the actual competition, target and player performance. Creation and post-race feedback retain their existing views and behavior.

## Requirements and delivered behavior

| ID | Behavior |
| --- | --- |
| CH01 / V03–V05 / R01 | Received/Sent cards show original scenery, track, competition/creator, formatted target or group lead, and expiry. The selected card has a restrained yellow edge. The shared menu header and Race mode rail remain. |
| CH03 / CH04 | Duel target stays pinned even when the creator's standing improves. Group leading time comes from an actual timed standing. No-time groups show Set the first time; missing player performances are omitted. |
| CH05 / R01 | Browsing has its own detail presentation, separate from the existing post-race feedback. A readable navy time panel accompanies the scenic actual route; the player's challenge best, signed gap and accurate success/tie/shared-lead state are shown. |
| CH01 / CH04 / V03–V05 | Four aligned standings columns show rank, driver, minute/millisecond time and signed gap in seconds. Yellow player highlight, all twenty group drivers and bounded scrolling remain. Final compact capture shows four complete rows. |
| CH06 / CH15 / R05 | Share, explicit Rematch, creator cancellation and existing start signals remain. Ended, exhausted and creator-duel race gates have explanatory captions. Guest Try track, authenticated Join & race, busy gates and five pinned laps remain. |
| V03 / Q01 | Race is the main yellow action when detail is selected; Create challenge becomes primary for a signed-in empty selection. Loading does not falsely claim an empty inbox. No source/test labels, invented opponents, rewards or social features were added. |

Benchmark reasoning is documented in the preceding owner review: [EA's Autolog manual](https://eaassets-a.akamaihd.net/eahelp/manuals/nfs-hp-remastered-switch-en.pdf) emphasizes friends' performances; [Forza's Rivals description](https://forza.net/events/featured-rivals-logitech-mclaren-qualifier-1) centers car/track/time comparison; [the historical DRIVECLUB challenge loop](https://blog.playstation.com/2014/06/02/how-driveclub-aims-to-make-rage-quitting-extinct/) connects finishes to friend challenges. The local composition is a design inference, not a claim to reproduce those games' current interfaces.

## Changed files

- `game/ui/challenges_page.gd`: Race-tab inbox/detail presentation and honest states; existing result-detail presenter retained.
- `game/tests/test_challenge_tab.gd` and `.uid`: isolated native presentation/action checks.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, and task evidence/checkpoint tooling.

`game/ui/challenge_create.gd`, `game/core/app.gd`, challenge adapter/backend/contracts and the existing challenge integration test were not edited by this task. The unchanged integration test and its task-start copy have SHA256 `2a3546b6f846bef12e717d6f088734cd1cbe4b3e3d40ee1d455defa610664380`. Creation source SHA256 at final review is `9d2d77f7ff456a2942bfd3c547577052183f2a0f234c45c9c7193709d76cff3a`.

## Actual commands and outcomes

Commands use the pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. PowerShell runs with process-local ExecutionPolicy Bypass; APPDATA points inside `build/challenge-tab-2026-10-10/` to isolate saves. Graphical integration captures set `BMT_CHALLENGE_CAPTURE_DIR` to this task's screenshots directory. Local-access execution is required because the sandbox denies Godot's system certificate-store read; no external service/player mutation is performed.

| Actual command | Outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_challenges.gd -Graphical -CommandTimeoutSeconds 150` | Final 140 checks, zero failures; eighteen captures at 1280×720, 960×540 and 1600×720. Includes actual App/menu integration, creation, locked completed result, pending verification, normal-result feedback, all group drivers and exhausted starts. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_challenge_tab.gd -Graphical -CommandTimeoutSeconds 120` | Final 63 checks, zero failures. Fixed duel target despite faster creator standing, own best/signed gap, real pointer selection, group bottom-row reachability, no-time groups, equal duel time, shared group lead, long names, busy/ended/cancelled/settling/exhausted/creator/guest/unjoined states covered. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp -CommandTimeoutSeconds 120` | 99 checks, zero failures. Ran before the last local spacing/tie-copy refinements; final graphical integration recompiled and exercised the App afterward. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import -CommandTimeoutSeconds 150` | Attempt failed while copying the already-loaded `~bmt_windows_audio_v3.dll`; not reported as a successful full import. |

An intermediate integration rerun failed because the generated class cache did not yet contain the concurrently added `GrassBirds`. Its existing `class_name`/Node/path entry was added to the ignored generated cache; the subsequent final App integration/captures passed. No unrelated ambience source, Windows native module, open editor or failing assertion was changed. An initial patch application failed due to hunk order and was reapplied successfully. Earlier native runs also passed140 and58/63 checks; they are not additional unique coverage.

Actual logs are retained in [integration.log](evidence/challenge-tab-2026-10-10/integration.log), [tab.log](evidence/challenge-tab-2026-10-10/tab.log) and [app.log](evidence/challenge-tab-2026-10-10/app.log). Initial cache/import failure logs are retained separately.

## Visual evidence and acceptance

- [Received duel, desktop](evidence/challenge-tab-2026-10-10/screenshots/received-1280x720.png)
- [Group, compact](evidence/challenge-tab-2026-10-10/screenshots/group-960x540.png)
- [Full group bottom, compact](evidence/challenge-tab-2026-10-10/screenshots/group-bottom-960x540.png)
- [Creation remains its existing view](evidence/challenge-tab-2026-10-10/screenshots/menu-create-1280x720.png)

Final desktop/compact screenshots were inspected. Displayed identities/times are isolated fixtures, never inserted into a live board. Existing cleared fictional car/scenic art and fonts are reused; no new generated/reference shipping asset is introduced.

Remaining acceptance: owner visual/wording review, actual phone/tablet touch and safe-area checks, long-lived background refresh/scroll behavior and signed-in real invitation/join/share flow. No phone attachment check or device test was performed. No APK export/install, new HTTP race, backend migration/deployment, purchase, physics change/merge or full Validate occurred. Existing challenge verification, durable/idempotent uploads and public/artificial isolation are unchanged.

Task-only review checkpoint: `refs/codex/challenge-tab-2026-10-10`; inspect with `git diff refs/codex/challenge-tab-2026-10-10^ refs/codex/challenge-tab-2026-10-10`. The checkpoint preserves the live branch/index and concurrent work. Receipt: `docs/evidence/challenge-tab-2026-10-10/checkpoint.json`.
