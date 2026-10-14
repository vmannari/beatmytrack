# Backend deployment â€” 2026-10-12

Owner request: `deploy backend`. Target: existing retained Google Cloud staging service; requirement IDs STUDIO-LOCAL-DRAFTS-01, STUDIO-CATALOGUE-01, STUDIO-RACE-PACKAGE-01, STUDIO-MONITOR-01, B05/B07/Q01.

Deploy the previously prepared, frozen Studio/publication backend candidate, not the dirty workspace. The 35-file backend overlay preserves the deployed game/compiler package. Its scope includes local-only drafts, explicit verified publication, published catalogue and race statistics/monitor views. See the packaged proof and rollout receipt in `docs/evidence/studio-monitor-deploy-2026-10-12/` for exact changed paths and hashes.

Actual commands: `.tools/backend-venv/Scripts/python.exe .tools/studio_monitor_rollout_20261012.py maintenance`, `stopped`, `migrate`, `canary`, `promote`, `smoke`; subsequent browser and cleanup results are recorded in the receipts. The first sandboxed cloud call failed before mutation; the authorized network rerun succeeded. Cloud Logging propagation initially delayed the stopped-writer result; rereading the same completed job succeeded without rerunning its database snapshot.

Exact candidate acceptance: 217 SQLite tests and 335 PostgreSQL tests passed, eight skips in each run; 53 maintenance checks and 27 browser checks passed. Successful database backup: 1791815457222. Migration 0027â†’0028â†’0029â†’0030 preserved all checked existing counts/hashes: 408 players, 4311 runs, 2883 race personal bests, plus track/version, lap PB, purchase, entitlement and resume state. New publication/statistics tables began empty; no records were fabricated.

Canary revision `bmt-stg-e7a444ab-api-00044-kin` verified schema30 and fourteen UI asset hashes at zero traffic before promotion to 100%. The original single worker resumed; no extra always-on instance was added. Completion and maintenance timestamps, image digest, final worker/native/storage/browser checks and tag cleanup are authoritative in `rollout.json`, `verify-live.json` and the live-browser receipt.

Limits: this scoped release retains the deployed gameplay/compiler contract, so local compiler/speed-bump and other unrelated workspace changes are not shipped. Real store/ad fulfillment and unavailable operational/financial sources remain unavailable. No Android build, phone test, installation or real Google sign-in test was performed. Backup success does not claim a rehearsed restore. Owner review of the live Studio remains.

Completed at **17:38:57 Helsinki**. Live native/storage/schema checks passed with one ready worker and fourteen matching assets. `.tools/backend-venv/Scripts/python.exe .tools/studio_monitor_live_browser_20261012.py` passed **18 GET-only checks**, zero API writes or synthetic records; desktop/mobile captures retained and desktop quality capture inspected. The rollout `finish` command confirmed all targets and removed temporary tags. Maintenance lasted approximately **3m12s**.

Follow-up: the owner reported the unresolved racing mismatch. The matching compiler25/physics54 verifier and27immutable official revisions were subsequently deployed; see [matching rollout](MATCHING_VERIFIER_DEPLOY_2026_10_12.md).
