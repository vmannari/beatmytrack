# Track of the Day featured event page

2026-10-28. Requirements TDV01–TDV04 / R01 / Q01.

The daily pick now has a dedicated event composition instead of a browser card
followed by full-width controls. A large scenic route panel carries the biome,
UTC selection date, track name and creator. The separate race panel groups the
five-lap format, actual rating, car selector and prominent Race action. A clock
chip holds the authoritative countdown. Narrow component widths stack the two
panels with scrolling. Loading, failure and empty-day states keep the composition
and provide a clear status; Retry becomes the primary available action.

| Requirement | Result |
|---|---|
| TDV01 | Larger feature image, exact supplied route, strong title/creator hierarchy and compact countdown. |
| TDV02 | Dedicated car/action panel; Race remains visible without scrolling at the three reviewed landscape sizes. |
| TDV03 | Matched loading/unavailable/empty states; old route/rating/countdown are hidden while authority is pending or unavailable. |
| TDV04 | All five biome illustrations, long names, keyboard focus, twelve-language layout and a stacked narrow component layout. |
| R01 | Public/authenticated reads, serialized refresh, 503 retry, midnight refresh and immutable pre-race revision check retained. |
| Q01 | Native before/after views, actual pointer activation and retained App/navigation regressions. |

Only two runtime files change: `game/ui/track_of_day_page.gd` and the new
`game/ui/track_of_day_art.gd`. The art subclass reuses the existing TrackTile
route sampler, projection cache and authored biome images. The background is an
illustration; the overlaid route comes from the feed metadata. There is no new
AI art, download, live 3D preview world or external dependency. A shared 8×256
gradient texture supplies continuous caption shading; route framing reserves
the actual caption height so long titles cannot cover the route. Countdown
text updates once per displayed second and refreshes on language changes.

The new `game/tests/test_track_of_day_presentation.gd` exercises the actual App
page with explicitly synthetic feed responses and the bundled Lantern Village
route. The selected track/rating/day in these images are a test fixture, not a
claim about the current online daily selection. Existing tests are unchanged.
All records, caches and user directories are isolated inside the workspace.

Actual commands through the pinned engine's required development entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-page-2026-10-28/run.ps1 -Phase before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-page-2026-10-28/run.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-page-2026-10-28/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-page-2026-10-28/run.ps1 -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-page-2026-10-28/run.ps1 -Headless -ScriptPath res://tests/test_app.gd
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-of-day-page-2026-10-28/run.ps1 -Headless -ScriptPath res://tests/test_race_mode_input.gd
python scripts/text_encoding.py --json docs/evidence/track-of-day-page-2026-10-28/text-encoding.json
```

Final outcomes:

- Native Compatibility **74 checks, 0 failures**, with **15 views**.
- Native desktop Mobile **74 checks, 0 failures**, with **15 views**.
- Existing App **141 checks, 0 failures**, including its ordinary race flow.
- Existing Race-mode input **57 checks, 0 failures**.
- All 13 displayed message templates have populated translations and matching
  placeholders in all twelve catalogues: **156 checks, 0 errors**. No new copy
  or catalogue edits are needed; this is not a global translation-completeness
  claim.
- Bundled text scan: **1,552 files, 0 encoding issues** at the recorded checkpoint.
- Task-only source patch passes reverse application and whitespace checks.

The original page was captured with the initial fixture (30 baseline checks).
The first implementation passed 27 headless / 39 native checks; visual review
found overlapping translucent shade bands and excessive route/title proximity.
Continuous shading and caption-aware framing replace them. A second native
review passed 50 checks per renderer but exposed low-contrast focus text on the
gold button; local focus/pressed icon colors now retain dark ink. Final tests
add the twelve-language layout checks. Trial views remain under `initial-banded/`
and `initial-focus/`. An initial catalogue probe lost a literal ellipsis through
the Windows shell pipe and reported twelve missing keys; the corrected probe
uses an escaped Unicode character and passes all 156 checks. Its original
result is retained. A duplicate-path patch attempt was rejected before mutation
and was replaced by a single-file update.

The runner archives each log/receipt and restores only its own generated build
identity/version when still current. Concurrent source changes and newer build
identities remain; no whole-workspace freeze is claimed. The source checkpoint
contains the two runtime scripts and new presentation fixture. Documentation,
runner, source hashes and verification receipts accompany it.

[Before](evidence/track-of-day-page-2026-10-28/before/gl_compatibility/ready-1280x720.png)
→ [final Compatibility](evidence/track-of-day-page-2026-10-28/after/gl_compatibility/ready-1280x720.png)
and [desktop Mobile](evidence/track-of-day-page-2026-10-28/after/mobile/ready-1280x720.png).
[Small landscape](evidence/track-of-day-page-2026-10-28/after/gl_compatibility/ready-844x390.png),
[Finnish](evidence/track-of-day-page-2026-10-28/after/gl_compatibility/finnish.png),
[unavailable](evidence/track-of-day-page-2026-10-28/after/gl_compatibility/unavailable.png),
[narrow component](evidence/track-of-day-page-2026-10-28/after/gl_compatibility/narrow-race.png).
The narrow capture tests this component independently of the global menu header.

Reload/rebuild and owner appearance acceptance remain. No physical-device test
or attachment query, APK, live/backend write, real-account authentication,
purchase, owner-save change, owner-process restart, deployment or main-index
staging/commit/merge was performed. The request's AAA goal is a quality direction;
these desktop checks do not establish phone appearance, frame pacing, thermal
cost or a production-quality certification.
