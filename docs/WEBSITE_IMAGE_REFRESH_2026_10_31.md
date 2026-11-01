# Website game-image refresh — 31 October 2026

The race and editor images described below were subsequently replaced with Blind Spot captures; see the [Blind Spot update](WEBSITE_BLIND_SPOT_2026_10_31.md) for the current live revision and screenshots.

The owner requested more attractive gameplay liveries, the actual five-biome Create screen, and an up-to-date Garage image. The refreshed [public staging website](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/) now shows:

- Two native race views: orange/cream Endurance and teal/cream Rally Blocks liveries. The pictures come from a real 480-tick game simulation, with consistent 4-second race time and 34 km/h HUD. The orange image also supplies the social preview.
- The current Create biome picker, showing Grass, Desert, Night, Winter and Storm. This replaces the incorrect four-environment list.
- A current track editor capture and the current Garage vehicle carousel, showing a red/cream Rally. Website copy uses the current six-vehicle catalog rather than retired names.

## Evidence and validation

All five images were captured from the actual game at 1280×720, with isolated disposable profiles and the backend disabled. The Garage test passed 83 native checks; the Create capture verified exactly five cards; the final gameplay capture verified actual livery bindings and exited without errors or warnings. The synthetic editor circuit and Guest profiles contain no owner data. Godot reported screenshot-related frame hitches during gameplay capture; these images are not performance evidence. All noninteractive Godot launches used `scripts/run_no_crash_dialog.py`.

The website WebP assets are lossless encodings whose decoded RGB pixels match the source captures exactly. [Race: Endurance](evidence/website-image-refresh-2026-10-31/gameplay-endurance.png), [Race: Rally Blocks](evidence/website-image-refresh-2026-10-31/gameplay-rally-blocks.png), [Create](evidence/website-image-refresh-2026-10-31/create-biomes.png), [editor](evidence/website-image-refresh-2026-10-31/editor.png), [Garage](evidence/website-image-refresh-2026-10-31/garage.png), and [desktop website](evidence/website-image-refresh-2026-10-31/home-1440.png).

The website and outage suite passed 8 tests inside the frozen candidate image; the existing local browser review passed 135 checks. The live and no-traffic candidate each passed 17 direct HTTP checks and 125 read-only HTTP/Edge checks at four viewport widths. No real Google verification, account mutation, physical-phone test, schema migration, worker deployment or owner-process restart was performed. [Local browser results](evidence/website-image-refresh-2026-10-31/browser-results.json), [candidate checks](evidence/website-image-refresh-deployment-2026-10-31/candidate-browser-3y354id0/verification.json), [live checks](evidence/website-image-refresh-deployment-2026-10-31/live-browser/verification.json), and [release receipt](evidence/website-image-refresh-deployment-2026-10-31/resume-o9k07l23/deployment.json).

## Deployment

The staging API serves 100% traffic from `bmt-stg-e7a444ab-api-web-6377917b6e59`, image `website@sha256:6377917b6e59180cba26873578ffd7377aa6747e3b1c19d5074bc63dc43e0bcd`. Its previous revision `web-9f7cd85ce28e` is retained; the existing `website-preview` tag remains on its earlier revision `web-244328226403`. A package comparison found exactly nine changed website files, with 351 baseline files and 358 final files. Runtime configuration is unchanged. [Frozen source hashes](evidence/website-image-refresh-2026-10-31/release.json).

The first deployment attempt created an untagged no-traffic candidate that Cloud Run marked retired; the readiness guard stopped before moving traffic. The existing revision was then activated using an additive temporary tag, checked and promoted. The temporary tag was removed after verification. [First attempt](evidence/website-image-refresh-deployment-2026-10-31/release-skvr38hz/preflight-stop.json).
