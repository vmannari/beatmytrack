# Documentation index

Reviewed against workspace source on **2026-10-24**. Use the guides below for current
behavior. Dated reports and the older portions of status/plan files record what was
implemented and tested at that checkpoint; their use of “current” does not make them
the present contract. The preserved blueprint remains an original proposal.

| Topic | Current entry point | Implementation to consult |
|---|---|---|
| Run, build and checks | [Repository README](../README.md) | [Development wrapper](../scripts/dev.ps1), [engine pin](../godot-version.txt), [project settings](../game/project.godot) |
| Menus, racing and authoring | [Menu and creator guide](MENUS_AND_CREATOR.md) | [App](../game/core/app.gd), [race rules](../game/race/race_rules.gd) |
| Track format and limits | [Creator format](CREATOR_FORMAT.md) | [Document validator](../game/editor/track_document.gd), [capacity policy](../game/editor/creator_limits.gd), [v5 schema](schemas/creator-track-v5.schema.json) |
| Discovery and offline content | [Discovery protocol](DISCOVERY_PAGING.md), [cloud integration](CLOUD_TRACKS.md) | [Cursor windows](../game/backend/discovery_windows.gd), [cloud adapter](../game/backend/cloud_tracks.gd), [v3 API](../backend/bmt_backend/discovery_v3.py) |
| Cars and controls | [Driving diagnostics](DRIVING_PLAYGROUND.md), [slide touch controls](TOUCH_SLIDE_ACTIVATION_2026_10_23.md), [camera options](CAMERA_OPTIONS.md) | [Car catalogue](../game/vehicle/vehicle_catalog.gd), [input settings](../game/project.godot), [touch controls](../game/ui/touch_controls.gd) |
| Garage appearance and free drive | [Appearance sync](GARAGE_APPEARANCE_SYNC_2026_10_23.md), [parking hall layout](PARKING_HALL_FLOOR_LAYOUT_2026_10_23.md) | [Garage](../game/ui/garage_page.gd), [parking hall](../game/garage/parking_hall_drive.gd) |
| Biomes and scenery | [Track themes](TRACK_THEMES.md), [Desert regression correction](DESERT_VISIBILITY_REGRESSION_2026_10_24.md) | [Theme definitions](../game/track/track_theme.gd), [native visuals](../game/track/native_track_visual.gd) |
| Sign-in and account ownership | [Account setup](ACCOUNT_SIGN_IN.md), [remembered sign-in](REMEMBERED_SIGN_IN.md), [account ownership](ACCOUNT_OWNERSHIP.md) | [Account controller](../game/backend/account_controller.gd), [session vault](../game/backend/session_vault.gd) |
| Challenges | [Challenge contract](CHALLENGES.md), [current creation flow](CHALLENGE_PAGE.md) | [Creation UI](../game/ui/challenge_create.gd), [series service](../backend/bmt_backend/challenge_series.py) |
| Weekly Rivalry and World Ranking | [Weekly Rivalry](WEEKLY_RIVALRY.md), [World Ranking implementation and launch gates](WORLD_RANKING_IMPLEMENTATION_2026_10_23.md) | [Rivalry API](../backend/bmt_backend/rivalry.py), [ranking API](../backend/bmt_backend/world_ranking.py) |
| Store | [Store reference](STORE_REFERENCE_2026_10_24.md), [purchase simulation](PURCHASE_SIMULATION.md) | [Store UI](../game/ui/store_page.gd) |
| Android | [Toolchain, commands and recorded deployments](ANDROID.md) | [Export preset](../game/export_presets.cfg), [development wrapper](../scripts/dev.ps1) |
| Backend setup and architecture | [Backend README](../backend/README.md), [architecture](BACKEND_V1.md) | [API composition/bootstrap](../backend/bmt_backend/app.py), [settings](../backend/bmt_backend/config.py) |
| Backend operations | [Deployment runbook](../backend/deploy/README.md), [latest recorded release](LATEST_BACKEND_DEPLOY_2026_10_23.md), [Studio activation](STUDIO_PLATFORM_ACTIVATION.md) | [Migration chain](../backend/bmt_backend/migrations/versions), [worker supervisor](../backend/bmt_backend/service_worker.py) |
| Privacy and moderation | [Account privacy](ACCOUNT_PRIVACY_2026_10_14.md), [public-content safety](PUBLIC_CONTENT_SAFETY.md) | [Privacy service](../backend/bmt_backend/privacy.py) |

The source currently uses five-lap rules `standing-5-road-gates-v23`, physics
`arcade-planar-0.66`, compiler `creator-compiler-27`, creator documents
`creator-track-v5` and native tracks `surface-grid-v2`. Imported creator documents
must use the current format. The public native catalogue contains Starter Circuit;
the retired Slicks corpus is diagnostic content.

Track themes are Grass (`pine`), Desert (`desert`), Night (`night_city`), Winter
(`winter`) and Storm (`storm`). Coast is retired. The creator allows up to 96 road
sections, 4,096 placed objects, independently 4,096 expanded tyre stacks, 1 MiB
documents and a provisional 128 MiB prop estimate. The estimate is an admission
bound, not device memory or frame-rate certification.

The latest recorded backend deployment is schema **0057**. The workspace also
contains subsequent challenge-series, World Ranking and game-configuration migrations;
their presence does not prove rollout. Consult each feature report and release receipt
before selecting matching client/API/worker artifacts. World Ranking requires its
declared prospective launch; production billing and broad Studio reporting have their
own configuration gates.

[Development status](../DEVELOPMENT_STATUS.md) and [Phase 0 plan](PHASE_0_PLAN.md)
retain the chronological checkpoints, failures and acceptance work. The
[documentation review](DOCUMENTATION_REVIEW_2026_10_24.md) records this reconciliation's
scope, source checks and limitations.

Game Configuration and required A/B testing: [implemented controls, validation and rollout limits](GAME_CONFIGURATION_IMPLEMENTATION_2026_10_24.md), with the [broader interface/use-case specification](GAME_CONFIGURATION_INTERFACE_SPEC_2026_10_24.md).
