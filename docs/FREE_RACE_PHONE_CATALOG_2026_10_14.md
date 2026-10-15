# Full Free Race catalog on the phone - 2026-10-14

The owner clarified that all 20+ published tracks must be playable from **Free Race**. The earlier nine saved drafts under Create -> Load Track did not satisfy that request. **FRP01-FRP03/R01/V05/Q01** cover the local catalog repair, compatible client/verifier deployment and actual browser/race acceptance below.

## Catalog and local-service repair

The existing public collection already contained **27 tracks**. Cached GET /v1/tracks succeeded, but the actual Free Race POST /v1/discovery/tracks returned503 DATABASE_UNAVAILABLE: the local PostgreSQL schema was0014_storage_lifecycle while the running source required newer migrations. Its old verifier also reported physics0.50/compiler20.

Before migration, the task backed up the existing bmt-pc-dev PostgreSQL database and object store to the private `build/pc-backups/20261014T175533206036Z/` directory, including SHA256SUMS and COMPLETE. This task migrated that existing database through0034_account_privacy and restarted only its matching local API/worker. Subsequent concurrent work applied0035_rivalry_car_appearance; final readiness reports that schema. Production, NAS and cloud services were not deployed.

All **30 original track identities** remain, including the27 published catalog entries. The upgrade helper validates every original published document with the matching native verifier before one database transaction, then adds immutable compatible revisions to those exact original identities. Original document IDs, names, creators/owners and old published revisions are retained. No source route, cosmetic tire geometry or canonical simulation was changed by this task. The final read-only counts are30 tracks/154 versions/118 boards/**82 personal bests/190 runs**. The original counts were30/100/64/82/190; new immutable revisions and uncompleted acceptance tickets explain the version/board increase. No completed race or score was submitted.

The final contract is physics **arcade-planar-0.59**, compiler **creator-compiler-27**, rules **standing-5-road-gates-v20**, five laps at120Hz. Both API manifest and catalog revisions match the frozen client/verifier. The27 titles remain distinct; Winter includes Slippery and Desert includes My way and Dust cloud. The [acceptance manifest](evidence/free-race-phone-2026-10-14/acceptance.json) records current readiness, exact contracts, titles and evidence hashes.

## Coherent deployment

Parallel work changed the shared workspace during an initial export. That installed attempt contained inconsistent road-height interfaces and could not launch a race. It was replaced with a complete source snapshot captured twice with identical shipping-text bytes. The snapshot directory is named `frozen-deploy-0.58` for historical reasons, but its actual pinned physics is **0.59**. No parallel source was reverted.

This task's coherent APK SHA-256 is **F3C25184F4CD4C24CAF7ABEAF441B7B81D290FEED7F4DF1A0DDF1960FB3938F5**;257743083 bytes. Its installed base.apk SHA was verified. A parallel phone deployment subsequently installed **145424136D3A53CF2793DE59D32A1115C9573C0572A4619C651688CD78E3D221**; that current installed hash is independently verified and its actual vehicle bytecode contains only **arcade-planar-0.59**. This newer APK is preserved. The final physical Free Race checks below use it, while the native full-catalog checks use this task's coherent0.59 snapshot. Install-r retains existing phone records and cosmetics. The parallel deployment repaired the nine saved drafts and transferred the27 published documents; see [its scoped report](PHONE_DRIVE_DEPLOY_2026_10_14.md).

Device: OnePlus DN2103, Android13, Mali-G77 MC9, Compatibility/GLES3.2. Pinned engine: Godot4.7.2 stable `ed1daf0bf`.

The matching local verifier image is `bmt-backend:phone-free-race-frozen-20261014`, image manifest-list SHA `71d59f3678aef96f9342c56905ff5b19686b4dbb9c99dbd3cc22c9a82fa0722b`. Its Linux engine SHA is `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.

## Acceptance

The explicit local-service native test [test_free_race_live_catalog.gd](../game/tests/test_free_race_live_catalog.gd) exercises the actual cloud/discovery/browser code. It refuses a nonlocal service before sending a developer credential, disables session saving, uses disposable local records and creates no completed race.

- Moving the actual browser gallery into page two automatically loads all20+7 discovery entries with27 unique identities; the test does not force a private page fetch.
- Every actual document passes download hash/schema validation and native compilation.
- Every Windows-native geometry hash matches its published Linux manifest.
- Every published track receives a compatible real five-lap race ticket.
- The actual Free Race browser retains all27 entries and the correct total.
- Final result: **142 checks,0 failures**,27 tracks. [Actual log](evidence/free-race-phone-2026-10-14/live-catalog.log).
- Export quick checks: APP_READY, Driving72, Catalog21 and Menus48, all passing. [Logs](evidence/free-race-phone-2026-10-14/checks/startup.log).
- Matching verifier image: canonical import, **12757-tick five-lap golden fixture** and ten-second rewind fixture all pass.

The parallel phone practice probe stopped at the owner's request after14 passing routes and restored its local records. This task then confirmed the actual Guest Free Race browser and launched **Winter Lonkero** and **Desert My way** through their normal Race buttons. Both reached rendered gameplay with running timers and **lap1/5**, followed by actual movement. No missing-function, parse, script or shader-fatal error appears in those captured logs. [Winter selection](evidence/free-race-phone-2026-10-14/winter-selected.png), [Winter gameplay](evidence/free-race-phone-2026-10-14/winter-gameplay.png), [Desert selection](evidence/free-race-phone-2026-10-14/desert-selected.png), [Desert gameplay](evidence/free-race-phone-2026-10-14/desert-gameplay.png).

The gallery also showed later entries including Looper, Starter Circuit, Sightseeing, Speedy, Ellipse, Silmukka and Blind spot. A subsequent physical end-of-gallery sweep overlapped active owner driving and is not counted as pagination acceptance. Touch input stopped when that activity was recognized; the task did not force the phone back to a menu. The actual second-page browser acceptance is the native test above. The phone's persistent public index held the20-entry first-page snapshot on readback, which is not a count of the whole27-entry paginated collection.

The captured Winter startup includes a **119.356ms tick0/countdown358** event. This availability check is not a hitch-free or phone-performance claim. The task submitted no completed race and performed no account sign-in on the phone; subsequent owner gameplay remains outside its acceptance measurements.

## Initial failures and corrections

The first catalog refresh imported an installed Python package rather than the mounted current source. It reused26 incompatible old revisions and added one compatible revision, without creating duplicate track identities. An initial inference that duplicates existed was incorrect. Read-only comparison against the pre-migration database backup confirmed zero new identities.

Automatic approval review rejected a proposed irreversible deletion of26 inferred duplicates because attribution was unproven and deletion exceeded the requested scope. That command did not run; no track was deleted and no archive flag was changed. The correct helper explicitly imports /app source and targets the27 original IDs. Temporary experimental changes to official_tracks.py and its test were restored byte-for-byte; no runtime backend source change is part of this task.

A mixed0.57/0.58 client test also produced27 expected contract-mismatch failures, and an attempted mixed acceptance snapshot failed import. These are retained as failed attempts privately. The final coherent0.59 pair replaces them; failed screenshots/loading overlays do not establish gameplay acceptance. Initial use of the private nonexported Android activity was corrected to the ordinary GodotAppLauncher activity. A final retention query used the wrong board table name and was corrected with the actual `boards` table; both queries were read-only.

## Reproduction and limits

```powershell
# Use the matching frozen project, with the local development key in process env only.
$env:BMT_API_URL = 'http://127.0.0.1:18181'
powershell -NoProfile -ExecutionPolicy Bypass -File build/free-race-phone-2026-10-14/frozen-deploy-0.58/scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_free_race_live_catalog.gd -CommandTimeoutSeconds 240
adb -s PRQKU4U4PREQNRWG reverse tcp:18181 tcp:18181
```

The phone currently uses the local PC development service through USB/ADB reverse18181. Disconnecting/restarting ADB can require restoring that forwarding; this is not a production endpoint rollout. Future changes beyond the frozen0.59 source need a new coherent client/verifier export. The final guarded native test initially omitted BMT_API_URL and correctly stopped before sending credentials; its successful run explicitly sets that local URL. No new phone FPS, hitch, thermal, all-route completed-driving, full Validate or production scoring acceptance is claimed.

Private source documents, database backups, credentials, device records and failed/intermediate artifacts remain under ignored build directories. Curated text logs use UTF-8 with normalized line endings and trailing whitespace; raw originals remain privately available. The initial checkpoint whitespace check exposed generated-log trailing spaces, which were corrected in those curated copies. The task-only source/documentation/evidence checkpoint is `build/free-race-phone-2026-10-14/checkpoint-repo`; its [checkpoint manifest](evidence/free-race-phone-2026-10-14/checkpoint.json) records the exact scoped commit and passing whitespace/reverse-patch checks. It excludes all parallel rendering/tire/handling changes and does not mutate the shared main Git index or HEAD.
