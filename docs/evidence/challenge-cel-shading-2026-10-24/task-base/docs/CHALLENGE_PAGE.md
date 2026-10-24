# Current challenge creation and presentation

Reviewed 2026-10-24 against [ChallengeCreate](../game/ui/challenge_create.gd),
[CarShowroom](../game/ui/car_showroom.gd) and [App](../game/core/app.gd).
Creation proceeds through format, track selection and car selection. All five cars
use the actual Garage models and showroom; the abstract studio was reverted.
Ordinary time lookups are quiet and keep layout stable. Use personal best uses the
verified selected track/car source, while post-race creation retains its exact ticket.
The carousel's end animation moves the whole card row.

The refined scenic v2 illustrations at the first checkpoint below are current;
the later-listed native-diagram replacement is superseded. The 3?3 format requires
the matching schema0058/API/worker rollout and service capability. See
[challenge contracts and rollout status](CHALLENGES.md),
[stable lookup evidence](evidence/challenge-checking-layout-2026-10-23/report.json),
[whole-row carousel evidence](evidence/challenge-carousel-edges-2026-10-23/report.json)
and [restored Garage evidence](evidence/challenge-garage-restored-2026-10-23/report.json).

## Implementation checkpoints

The records below retain the exact behavior, assets and tests at each stage.
Statements about large car illustrations, a separate abstract studio or a two-column
creation sheet describe earlier revisions.

---

# Refined scenic challenge illustrations - 2026-10-23

CIR01-CIR03 supersedes the rejected native-diagram presentation. The owner prefers the earlier scenic racing and garage pictures, with less conspicuous generated detail and accurate construction. Five versioned v2 edits preserve those subjects: the blue car on a forest bend, a garage planning workbench, two rival hatchbacks, a six-car grid and three distinct closed circuits with three start lights each.

The revisions use softer natural lighting, dry asphalt, simpler materials and more coherent car, wheel, road, barrier and garage objects. The workbench has three separate closed route maps, one central-hand stopwatch, a pencil and folded checkered cloth; a targeted second edit removes the parked car's badge and tiny lettering. The 3x3 format shows its complete illustration above the caption so all circuits and starts remain visible. Entry pictures remain different. The earlier scenic route-card/detail/picker presentation is restored; Find & play remains a dedicated finding/racing destination with no creation options. Actual Garage cars, timing, verification, attempts and account checks remain.

The built-in image_gen tool edited the original project images. Original PNGs and provenance are retained. Versioned workspace files and the exact prompt set, references, cleanup and hashes are in [refinement-v2.json](../game/assets/menu/challenges/refinement-v2.json). Each runtime import remains lossless, mipmapped and capped at1024px on the long side.

[Entry preview](evidence/challenge-art-refinement-2026-10-23/entry/Windows-gl_compatibility/entry-1280x720.png) and [format preview](evidence/challenge-art-refinement-2026-10-23/creation/Windows-gl_compatibility/formats-1280x720.png). Actual native checks, source/asset fingerprints and scoped checkpoint: [report](evidence/challenge-art-refinement-2026-10-23/report.json). Owner appearance acceptance and physical-device readability remain; no phone/tablet attachment check, device test, APK/export/install, live account/backend mutation, social send or deployment by this task.

---

# Native challenge graphics - 2026-10-23

The owner rejected the generated challenge pictures. CNA01-CNA03 replaces entry and format illustrations with original native diagrams: a circuit search, format/track/car planning, a duel, a starting grid and three circuits with three attempt dots each. Challenge race cards, selected race/result/invitation previews and the creation track picker use circuit maps on a restrained navy grid. Race maps retain the actual track points; the format symbols are decorative diagrams. The two entry choices remain distinct.

The three-step creation flow, separate Find & play browser, exact times and verified sources remain. Ordinary Free Race keeps its existing art by default, and challenge car selection retains the actual Garage showroom. The earlier poster presentation in this document is superseded; its original assets and provenance remain historical records. No new bitmap, runtime generation, provider or dependency is introduced.

[Entry preview](evidence/challenge-native-art-2026-10-23/entry/Windows-gl_compatibility/entry-1280x720.png), [race browser](evidence/challenge-native-art-2026-10-23/browser/discover-1280x720.png), [formats](evidence/challenge-native-art-2026-10-23/creation/Windows-gl_compatibility/formats-1280x720.png). Actual checks, source hashes and scoped checkpoint: [report](evidence/challenge-native-art-2026-10-23/report.json). Client reload and owner appearance/device acceptance remain; no phone/tablet attachment check, physical-device test, APK, account/backend mutation or deployment by this task.

---

# Challenge flow, artwork and car step — 2026-10-23

2026-10-23 CFL01-CFL05/R01/G01/Q01: Challenge creation now runs format -> tracks -> car with Next actions. Three original built-in imagegen posters depict a duel, a pack and three circuits/three starts; bounded1024-long-side mipmapped imports replace biome-only illustrations. Custom rules occupy the full page with transactional Back/Next. The actual Free Race TrackBrowser supplies virtual cards, Search/Filters/Random/refresh and bounded discovery, without a mode rail, downloads or a race action in selection mode. Single-track selection removes the redundant top button; 3x3 has functional outlined slot tabs. A dedicated five-car page offers creation/sharing, group Create & race, and the original verified source drive. Race intent waits for the folder read and cancels on account/selection/navigation changes. Focused80headless/93Compatibility/93desktopMobile, integrated255, discovery68, shared FreeRace233, race-intent8, App141, parser987 and real canonical HTTP2 pass. Actual commands, native views, asset prompts/provenance, scoped hashes and checkpoint: docs/evidence/challenge-flow-polish-2026-10-23/report.json. Owner appearance/flow and physical-device acceptance remain; existing3x3 matching-server rollout is unchanged. No phone attachment check/device test, APK, live backend/account mutation, social send or deployment. Concurrent work preserved.

Format, tracks and car are separate steps with Next between them. The three full-frame format illustrations depict two rivals, a pack and three circuits with three starting lights each; scenic biome-only posters and extra vector overlays are removed. Native selected/focus frames and the subtle custom action remain. Full prompts, built-in provider, source paths, copied project assets and hashes are retained in game/assets/menu/challenges/generation.json.

Custom rules use a full menu page with four groups. Next commits supported mode, duration, tries and visibility; Back cancels the complete draft. Track selection embeds the real Free Race browser in metadata-only selection mode, reusing its virtual grid, scrolling, favorites, Search, Filters, Random and refresh. One track has no redundant top selector; three tracks use real outlined slot tabs. Ordinary Free Race retains its previous behavior by default.

The next page selects one of all five authored cars with a large existing illustration, description and carousel. Creation and racing are available here. Duel creation requires a verified target; a missing target offers the actual source drive. Group/3x3 offer Create & share and Create & race. Post-race track/car/exact-ticket pinning and verification persist; a source drive returns directly to this final page with its rules/tracks/car retained. Create & race waits for the Created-folder read, then cancels if its navigation, account or selected challenge changed.

No backend contract or live deployment changes are included; 3x3 still requires the prior matching0058/API/worker rollout. Physical-device touch/readability and owner art acceptance remain.

[Format](evidence/challenge-flow-polish-2026-10-23/integrated-gl_compatibility/menu-create-1440x900.png) · [Track selection](evidence/challenge-flow-polish-2026-10-23/integrated-gl_compatibility/menu-three-tracks-1440x900.png) · [Cars](evidence/challenge-flow-polish-2026-10-23/integrated-gl_compatibility/menu-car-selection-1440x900.png) · [Custom](evidence/challenge-flow-polish-2026-10-23/integrated-gl_compatibility/menu-custom-rules-1440x900.png).

---

# Format-first creation and 3×3 — 2026-10-23

2026-10-23 CFS01-CFS03/R01/G01/Q01: Challenge creation is format-first with One-to-one, Group race and 3×3 scenic posters, a subtle Create custom challenge action and a separate biome-style track picker. One invitation pins three distinct tracks and one car; independent three-start budgets feed verified best-only summed standings, stage tickets/ghosts, account/block/deadline fences and one reward identity. Exact finished results remain stage one; ordinary groups need no source request. Legacy list clients opt out of 3×3, while capability-gated creation requires schema0058/API/worker updates. Native focused62headless/71Compatibility/71desktopMobile, series30, integrated239, discovery68 and parser971 pass; backend SQLite39pass/2skip, PostgreSQL40+1 and privacy/maintenance21 pass. The two concurrent editor App assertions reproduce with challenge changes removed; a legacy rollback also reproduces on original challenge modules. Actual commands, corrections, native views, hashes and scoped checkpoint: docs/evidence/challenge-format-series-2026-10-23/report.json. Owner visual/flow and physical-device acceptance, matching server rollout remain; no phone attachment check/device test, APK, live account/backend mutation, social send or deployment. Concurrent work preserved.

Creation opens with three format posters using the creator biome selector’s full scenic frame, square edge, gold selected label and bottom action dock. The track and time hero is removed from this first step. Custom is a secondary action; applying its optional rules advances to track selection. Back preserves selections.

The second step chooses one track, or three distinct tracks for 3×3. Three slots retain choices while browsing/searching bounded catalogue results. A completed source race pins slot one and the car; its exact verified time uses one of that track’s three starts. Ordinary group/3×3 creation is target free. A missing duel target still offers the original real source drive.

3×3 uses one Challenge/member/reward identity with three ChallengeStage rows, three stage-member rows per driver and stage-ticket bindings. Each start, restart or abandoned race consumes one try on that track; only verified best results enter scoring. Drivers need a result on every track for a total/rank. The sum of the three best times wins; incomplete drivers show completed tracks. Per-track race and ghost requests use ?stage=0/1/2. All tracks retain availability/creator-block/build checks. Public and personal lists include 3×3 only with series=1, preserving old client list validation and cursor identity.

Roll out migration 0058_challenge_series, API and verification worker together before new client acceptance. Bootstrap advertises challenge_series_version=1; current older services keep the track page’s Create disabled with an update notice for 3×3. Existing single-track API bodies/idempotency scopes remain unchanged. Downgrade refuses to discard existing 3×3 stages. No live rollout was performed.

[Native format page](evidence/challenge-format-series-2026-10-23/integrated-gl_compatibility/menu-create-1440x900.png) · [Native track page](evidence/challenge-format-series-2026-10-23/integrated-gl_compatibility/menu-three-tracks-1440x900.png) · [Evidence](evidence/challenge-format-series-2026-10-23/report.json).

---

# Challenge composition refinement — 2026-10-23

2026-10-23 CCL01-CCL03/G01/R01/Q01: Refine the owner-supplied challenge screenshot with an adaptive four-poster grid, larger original vector format illustrations, cropped shared scenery, stronger type/selection states and a single nearby rules/action dock. Remove the repeated selected-mode panel and detached footer copy; circuit/car choices are explicit secondary controls and the actual target has a quiet inset. Existing Custom rules, exact completed-ticket results, verification/account fences, source drive, finite tries and sharing remain. Focused118headless/133Compatibility/133desktopMobile, integrated native challenge235 including the taller1440x900 window, and parser944 pass. Native views, actual commands, source fingerprints, limitations and task-only checkpoint: docs/evidence/challenge-layout-refinement-2026-10-23/report.json. Owner visual/feel and physical-device touch/readability acceptance remain; no phone attachment check/device test, APK, live account/backend mutation, social send or deployment. Concurrent work is preserved.

This presentation pass replaces the shallow thumbnail strips and separated summary/footer with taller adaptable format cards and one action dock. Each format uses original native vector artwork; existing scenic images are cropped without distortion. No additional raster asset, live scene, frame target or polling timer is introduced. The four format choices, supported rules and authoritative source/result contracts remain as described below.

[Refined full menu at the owner’s taller aspect ratio](evidence/challenge-layout-refinement-2026-10-23/integrated-gl_compatibility/menu-create-1440x900.png). [Detailed evidence and remaining acceptance](evidence/challenge-layout-refinement-2026-10-23/report.json).

---

# Native card refinement — 2026-10-23

2026-10-23 CCR01-CCR04/G01/R01/Q01: Apply the approved HTML challenge-card direction to the native menu: Choose your challenge, Head to head, Group race, Three tries and a fourth Custom rules card. Optional rules commit/cancel race type, 24-hour/3-day/7-day duration, 1/3/5/unlimited tries and supported public/invitation visibility; preset changes retain duration and visibility. Actual route/car/time lead the page, with fixed completed-ticket results, verification/errors/account fences, five laps, verified-PB menu sources and target-free groups retained. Race-first return preserves the selected format; an account-fenced frozen invitation precedes explicit system sharing. Focused97headless/109Compatibility/109desktopMobile, native challenge195, discovery68/source27/tab60/App141 and parser939 pass. Commands, initial environment/fixture/layout corrections, native views, hashes and task-only checkpoint: docs/evidence/challenge-cards-native-2026-10-23/report.json. Owner appearance and physical-device touch acceptance remain; no phone attachment check/device test, APK, live backend/account mutation, social send or deployment.

This replaces the initial settings/preview form layout described below. The existing creation API, scoring and verification contracts remain. Custom rules uses the supported race type, duration, tries and visibility choices. It does not introduce an unverified target, editable lap count or a new backend title field. Existing menu sources may use a verified PB and groups may open without a target; completed-result creation always uses its exact ticket.

The main native implementation is `game/ui/challenge_create.gd`, supported by `challenge_format_card.gd` and `challenge_ready_dialog.gd`. `game/core/app.gd` retains the card configuration across the source drive and opens the frozen invitation before explicit sharing. The focused native checks are `game/tests/test_challenge_cards.gd`; existing challenge/discovery checks were updated for the approved layout, retaining the original exact-result, finite-try, group and account invariants.

Native screenshots: [four-card menu](evidence/challenge-cards-native-2026-10-23/integrated-gl_compatibility/menu-create-1280x720.png), [optional rules](evidence/challenge-cards-native-2026-10-23/Windows-gl_compatibility/custom-rules-1280.png), [invitation](evidence/challenge-cards-native-2026-10-23/Windows-gl_compatibility/ready-1280.png). See the report for actual commands, earlier failed attempts and remaining acceptance.

---

# Challenge creation page and attempt limits ? 2026-10-09

The owner supplied a two-column Create challenge draft and requested optional limits on tries. Creation now occupies the main menu below its existing navigation, with settings on the left and the original scenic art, actual route and live summary on the right. Back/Cancel and Create & share stay outside the cards. All six setting rows fit the default desktop, compact and wide landscape layouts; opening track search or the tries explanation uses the bounded settings scroll.

## Requirements

| ID | Implemented behavior |
| --- | --- |
| CH14 / V03?V05 / R01 | Embedded two-column creation page replaces the centered CanvasLayer sheet. Existing original scenery, vehicle artwork, typography and yellow controls are reused; car/share glyphs extend the original vector icon set. |
| CH15 / B01?B07 | Optional 1, 3, 5 or unlimited tries per driver; unlimited remains the default. Server ticket issuance atomically reserves a try. Abandoned/restarted/rejected races consume their reserved tries; reconnect/upload retries do not reserve another. Exhausted participants can inspect/share results, but cannot start another challenge race. |
| CH16 / Q01 | Additive schema0021 keeps old challenges unlimited, backfills their starts/source finishes and preserves standings. Existing default creation idempotency hashes are retained. Parallel same-key starts share one ticket; competing requests cannot exceed the limit. Explicit rematches retain the chosen limit and create fresh counters. |
| CH09?CH11 / CH02?CH04 | Post-race creation still fixes the exact completed ticket, track and car, including a slower-than-PB finish. Pending/error states never substitute a PB or offer another drive. Cancel restores the same normal summary. Source-race return retains duration and tries. A seeded creator finish counts as one try; a Group created without a source starts at zero. |
| R01 / R05 / TD06?TD08 | Five pinned laps, normal results first, best-only standings, free ordinary racing, internal authentication gates and artificial/public isolation remain. |

No unverified custom target, public/community visibility, 14-day duration or new social feature was inferred from the illustrative draft. Existing verified targets and 24-hour/3-day/7-day durations remain. General creation keeps track/car selection and optional track/creator search; finished-result creation keeps those values fixed.

## Changed files

- `game/ui/challenge_create.gd`: page layout, preview/summary, tries choices and help, selected-limit submission.
- `game/core/app.gd`: menu integration, completed-summary retention/return and source-race settings.
- `game/ui/challenges_page.gd`, `game/backend/challenges_client.gd`: remaining tries, exhausted race gate, response validation and ticket counter updates.
- `game/ui/menu_icon.gd`: original car/share SVG glyphs.
- `backend/bmt_backend/challenges.py`, `challenge_models.py`, `migrations/versions/0021_challenge_attempts.py`: optional contract, atomic reservations, snapshots, rematches, browser invitation and additive migration.
- `game/tests/test_challenges.gd`, `test_challenges_http.gd`, `backend/tests/test_challenges.py`: native layouts, actual HTTP races, attempt/idempotency/concurrency/migration coverage.
- `docs/schemas/challenge-create-v1.schema.json`, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and task evidence.

## Actual verification

All native checks use `scripts/dev.ps1` and pinned Godot4.7.2.stable.official.ed1daf0bf. Actual HTTP runs use an isolated local service, test identities and recorded five-lap races, rather than retained player data.

| Actual command | Outcome |
| --- | --- |
| `scripts/dev.ps1 CheckScript -ScriptPath res://core/app.gd` | Passed. First restricted attempt could not open the Windows user log; local-access parser passed. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_challenges.gd -Graphical` | 140 checks, zero failures at1280?720,960?540,1600?720; 18 captures. Exact result/pending/service-error behavior, page integration, all default rows visible and exhausted race controls covered. |
| `scripts/dev.ps1 TestApp` | 99 checks, zero failures. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s --tb=short` with `BMT_CAPTURE_CLOUD` | Final two native flows pass48/49 checks. A real faster PB is verified before the slower source finish; Cancel restores the same summary; exact source, race-first duration/tries, guest try, recipient ghost/race, normal results, retry, rematch and group scoring pass. |
| `.tools/backend-venv/Scripts/python.exe .tools/challenge_page_postgres.py` | Owned disposable SQLite/PostgreSQL runner; final receipt below. Row concurrency and actual schema0020?0021 over existing standings included; the owned container is removed. |
| `scripts/dev.ps1 Doctor` | OnePlus Pad2 OPD2403/f0ba474a attached and authorized. No change-specific Android test/install/export was performed. |

[Menu checks](evidence/challenge-page-2026-10-09/menus.log), [application checks](evidence/challenge-page-2026-10-09/app.log), [native HTTP log](evidence/challenge-page-2026-10-09/http-final.log), [database log](evidence/challenge-page-2026-10-09/postgres.log) and [device receipt](evidence/challenge-page-2026-10-09/doctor.log) retain actual outcomes.

Initial test-only issues were corrected without relaxing assertions: wrong `steer` argument (fixture uses `steering`), a statically impossible type check, duplicate default page content, early layout assertions before the engine's layout pass and the browser preview's missing tries text. An earlier native flow passed while its historical inputs-only prior-PB upload was rejected by concurrent verifier work; the final fixture records and verifies an actual app PB before asserting the slower finish. Concurrent optional-ghost storage work briefly caused two broader database fixture failures, then its own fixture correction restored the full suite. Earlier database failure evidence is retained. A later concurrent `NightAmbience` class required an importer refresh; final parser/test receipt below. Driving physics/verifier behavior and unrelated work were preserved.

## Evidence and acceptance

- [General creation page, desktop](evidence/challenge-page-2026-10-09/screenshots/menu-create-1280x720.png)
- [General creation page, compact](evidence/challenge-page-2026-10-09/screenshots/menu-create-960x540.png)
- [Exact completed-result creation](evidence/challenge-page-2026-10-09/http-final/create-from-results.png)
- [Race-first creation return](evidence/challenge-page-2026-10-09/http-final/create-after-seed.png)

Fixture names/times are test evidence only. The approved original scenic art is reused; the supplied draft is not a shipping asset. Desktop image inspection does not establish phone touch, safe-area or performance acceptance.

Remaining acceptance: owner presentation/feel, tablet touch/search/help/keyboard, actual authenticated finite-try races on the intended development service, and migration/API/worker rollout together. No retained backend/production deployment, player-data reset, purchase, physics merge, full Validate or APK export/install occurred. At the server boundary a try is reserved when a start ticket is granted; a subsequently failed local start remains reserved. Ordinary Free Race stays unlimited.

The task-only Git checkpoint receipt is recorded below. It preserves the existing branch/index and concurrent work; it is a review checkpoint, not a deployment or merge.


Final receipts: owned SQLite/PostgreSQL **58 passed, two SQLite row-concurrency skips**, including migration preservation, final-start races, same-key concurrency and old default creation keys. The final pinned importer completed and headless challenge recheck passed **122** checks; the graphical140-check captures remain unchanged. [Final headless log](evidence/challenge-page-2026-10-09/menus-final-headless.log). No required acceptance invariant was removed.

Review checkpoint: `refs/codex/challenge-page-2026-10-09`; inspect with `git diff refs/codex/challenge-page-2026-10-09^ refs/codex/challenge-page-2026-10-09`. The scoped snapshot parent includes concurrent ghost-storage changes, so this diff concerns creation/tries only. Receipt: `docs/evidence/challenge-page-2026-10-09/checkpoint.json`.
