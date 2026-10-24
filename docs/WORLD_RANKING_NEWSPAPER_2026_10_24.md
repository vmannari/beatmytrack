# World Ranking in the Garage newspaper — 24 October 2026

The Weekly Rivalry header no longer contains World Ranking or Circuit buttons. Garage → newspaper → World Ranking prints the published standings, with World/Country/Friends/Season views, own rank and points, pagination, Near me, ranking details and the Compact Circuit action. The ordinary Rivalry rail returns from the Circuit to the selected car's Rivalry.

Completed official Circuit weeks show a World Ranking panel above the final standings: weekly place, earned points, counting/reserve status, current points, net point change and places gained/lost. Unpublished weeks stay pending. Movement from a newer publication is never attributed to an older ceremony. Ordinary car Rivalries retain their existing scoring and do not acquire Circuit awards.

| Requirement | Implementation |
| --- | --- |
| RNP01 | Remove ranking navigation from the Rivalry header and ceremony; keep the existing track/detail/results flow and rail return. |
| RNP02 | Add a newspaper ranking list with its controls in the existing footer, compact heading, visible rows at 960×540, bounded 50-row pages/eight cursors and ten rows built per frame. |
| RNP03 | Show published weekly ranking movement prominently, including down/unchanged/new entry/pending/error states, with account/safety response fences. |
| R01 / G01 / Q01 | Native regressions, actual rendered captures, retained initial failures, source hashes and a task-only reviewable patch. |

Runtime files: `game/ui/weekly_rivalry_page.gd`, `weekly_rivalry_finale.gd`, `world_ranking_week_summary.gd`, `garage_news_menu.gd` and new `garage_news_ranking.gd`. Focused checks are in `game/tests/test_ranking_newspaper.gd`. No backend, ranking calculation, physics, save format or asset contract changes are required.

Reads occur on explicit ranking entry/refresh/navigation. Headlines do not fetch rankings, and background news refreshes do not rebuild the ranking. Sign-out, account/safety changes, hiding and departure clear/invalidate the previous view. Existing capability and announced-launch gates remain. The newspaper uses the existing authenticated, read-only ranking endpoints and official-entry signal.

The [machine-readable report](evidence/ranking-newspaper-2026-10-24/report.json) records actual commands, outcomes, hashes and limitations.

| Actual check | Result |
| --- | --- |
| Focused ranking/newspaper | 45 headless; 50 Compatibility; 50 desktop Mobile; zero failed assertions |
| Existing World Ranking / newspaper | 25 / 70; zero failed assertions |
| Existing native newspaper stories/page turns | 868 Compatibility; zero failed assertions |
| Rivalry / awards / App | 1115 / 64 / 141; zero failed assertions |
| Whole-project parsing | 1085 scripts; zero failures |

Reproduce with the retained runner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/ranking-newspaper-2026-10-24/run_validation.ps1 -Test test_ranking_newspaper -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/ranking-newspaper-2026-10-24/run_validation.ps1 -Test test_ranking_newspaper -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/ranking-newspaper-2026-10-24/run_validation.ps1 -Test test_ranking_newspaper -Mode mobile
```

The runner checks the exact pinned Godot version and isolates APPDATA under the workspace. The initial `scripts/dev.ps1` checks are retained; Windows sandbox userdata/certificate restrictions stop its strict error watcher before UI assertions. The retained runner uses that same pinned console executable with explicit logs and Dummy audio. The certificate-store diagnostic remains visible in successful offline fixture runs. No external API is configured or contacted by these fixtures.

The native newspaper story fixture exits successfully after all 868 assertions but reports four retained ObjectDB instances and one resource during shutdown. This is retained in its log; a clean engine shutdown is not claimed for that broader fixture.

Initial rendered checks caught offscreen ranking rows and a clipped weekly movement label. The final layout places ranking controls in the newspaper footer and weekly movement above the final standings; assertions require two complete ranking rows without scrolling at all three tested newspaper sizes and a visible weekly change label. The original unsupported headless newspaper GPU pixel probe was interrupted after it attempted to sample a nonexistent Dummy texture; its graphical replacement and raw output are retained. A concurrent Desert wind-envelope parser interruption is retained, and later current-source parsing passes without changing that task's files.

Native desktop previews: [newspaper](evidence/ranking-newspaper-2026-10-24/mobile/garage-ranking-1280x720.png), [small window](evidence/ranking-newspaper-2026-10-24/mobile/garage-ranking-960x540.png), [weekly results](evidence/ranking-newspaper-2026-10-24/mobile/weekly-results-1280.png). These use isolated synthetic fixtures; they are not live player data.

Client restart and owner appearance/flow acceptance remain. No phone/tablet attachment check or physical-device test, APK/export/install, backend mutation or deployment was performed. Existing concurrent work and owner processes were preserved. The scoped patch is a reviewable checkpoint, not a commit of the shared dirty workspace.
