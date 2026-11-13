# Checkpoint backend deployed while preserving results

3 November 2026. CPD01–CPD03/Q01 implement the owner's instruction: deploy the checkpoint fix without invalidating results.

The retained `beat-my-track` backend in `europe-west1` now runs the corrected checkpoint geometry. **The complete competitive manifest remains identical to the pre-deployment manifest**, including rules23, physics0.77, engine/compiler versions and every vehicle's handling/configuration identity. Existing boards, personal bests, lap bests, Rivalry groups/members/bests and Daily identities retain their previous keys. Previously verified results are not rescored against the new gates.

This supersedes the initial checkpoint task's proposed rules24 competitive-key bump. The corrected layout is independently versioned as **checkpoint layout24** instead. Client gate caches check that version; server descriptors use `geom:24:<document-hash>` and a matching native layout field. Old descriptors remain in their original namespace. Stale geometry is rebuilt without moving results to a new board. No schema migration, track republication, result deletion, result reset or historical rescore ran.

## Deployment and preservation checks

The main patch inherits the exact previously deployed image `ac96933019158207994bd88ff925ef1d7312de546d0503ada2dfe664af8f1fae`. Only six files are overlaid: the three race gate sources, new `road_gate_coverage.gd`, the native backend runner, and Python `trajectory_verifier.py`. The website preview receives the same patch over its own original image, retaining its website files. All ten existing API/Studio/worker/job definitions use the matching main patch; the website preview retains its separate matching image. Existing accounts, credentials, settings, resource limits and traffic routes are preserved.

Main image: `backend@sha256:6d5d253d9173d15b1f61becebfba19514ef05a741b911cd36d59f20d87d802cb`.

Website preview: `backend@sha256:e8e87a3cb4159cc53a338320383e64af8e04482fe09df6abbd9e15aa9a053a9e`.

Serving API revision: `bmt-stg-e7a444ab-api-00159-lip`; Studio: `bmt-stg-e7a444ab-studio-00032-kav`; website preview: `bmt-stg-e7a444ab-api-00160-bem`. The default API template was subsequently aligned with the main image without changing these serving routes. Existing local release receipts were updated for the next deployment.

Managed Cloud SQL backup **1793728518369** completed before service changes. The race-verification queue was empty at the pre-deployment snapshot. Read-only aggregate snapshots before and after the rollout match across all 13 checked result/catalogue tables:

| Table | Before | After |
| --- | ---: | ---: |
| Boards | 463 | 463 |
| Personal bests | 7358 | 7358 |
| Lap personal bests | 7361 | 7361 |
| Runs, all statuses | 20556 | 20556 |
| Rivalry groups | 35 | 35 |
| Rivalry members | 416 | 416 |
| Rivalry bests | 848 | 848 |
| Rivalry archived bests | 0 | 0 |
| Rivalry week plans | 95 | 95 |
| Track versions | 434 | 434 |
| Track-of-day bests | 0 | 0 |
| World-ranking standings | 0 | 0 |
| World-ranking careers | 0 | 0 |

These are aggregate preservation checks, not a byte-level comparison of private records. No private result rows or record fingerprints were exported. Stable manifests additionally preserve the keys used to find existing results.

## Actual validation

- Local descriptor/cache, historical-board, gate-span and trajectory regressions: **63 passed**. New checks preserve an old descriptor and stable rules identity while creating the independently versioned descriptor, and reject installation of an older layout under the new cache key.
- Revised local road/kerb/finish regression: **2787/0**; shortcut sweep: **5144** eligible candidates with no accepted large off-road or beyond-recovery cuts; hairpin regression **65/0**, including a real five-lap **47712-tick** drive with zero collisions/warnings and exact replay.
- Both exact Linux patch images: pinned engine import, **12757-tick** five-lap golden replay and ten-second rewind pass. Each image matches the complete live competitive manifest, rejects all **nine** historical hairpin bypasses, accepts the real five-lap sparse proof and reproduces **47712** canonical ticks.
- Live API and private Studio canaries pass. Post-promotion manifest equality, schema0072, result counts, one ready worker, layout24 native export, and native replay/storage smoke pass. Temporary canary tags and the release lock were removed; the original website-preview tag remains.

Actual staged commands, run through `.tools/backend-secure-venv/Scripts/python.exe`:

```text
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py inspect
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py prepare
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py build
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py test
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py push
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py backup
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py rollout
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py verify
build/checkpoint-road-coverage-deploy-2026-11-03/deploy.py receipts
```

The rollout script, frozen source hashes, sanitized acceptance/preservation receipts and task-only source checkpoint are retained in [the evidence directory](evidence/checkpoint-results-preserving-deployment-2026-11-03/). Private configuration, credentials, provider resource dumps and raw cloud-command logs are excluded.

Initial Cloud CLI attempts encountered sandbox access restrictions and a trusted-CA configuration issue. The authorised rollout used the existing verified Windows trust bundle with TLS verification enabled. During diagnostic inspection, a short-lived Cloud identity token was mistakenly printed in the chat; its value is excluded from artifacts, the local diagnostic was redacted, and the wrapper now prevents token output from being written to diagnostic files. The chat output cannot be retracted by this task.

No physical-device query/test, APK/export/install, local PC backend replacement, owner-game restart, owner-save change or main-index write was performed. Reload/rebuild the game to load the updated client geometry and cache version. Owner driving/appearance and device acceptance remain. Earlier checkpoint geometry evidence and the independently reproduced older bridge-test failures remain documented in [the initial task report](CHECKPOINT_ROAD_COVERAGE_2026_11_03.md).
