# Backend reuse fixes — 26 October 2026

**All five reviewed optimizations are implemented. The compatible backend update is live on 100% of API traffic.** Reload/rebuild the game to use the wallet freshness and smaller comparison-prefetch window; no running owner process was restarted.

Live revision: `bmt-stg-e7a444ab-api-rr-52affa59c6ec`. Image: `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend-reuse@sha256:174b65b00b7f8f6b1236df0d20d235f1c7436387789df37b4e9c017d0aa97bf0`.

## Changes

| Requirement | Result |
|---|---|
| BRF01: reusable previews | Released the existing exact-hash preview protocol and advertised `discovery_preview_version=1`. Live canary and public-endpoint checks returned20 current cards, omitted all known outlines on the warm request, and restored outlines when cache hints were empty. Ratings, availability and track identities remain current. |
| BRF02: wallet refresh | Quick client refreshes reuse a valid online wallet for15seconds. Rewards without an accompanying wallet force a read; purchases consume their authoritative response. A force request during an older in-flight read schedules a current follow-up. Pending purchase recovery bypasses freshness and retains its original operation key. Identity changes fence late replies. The deployed established-wallet read retains locked recovery for missing wallet/provenance. |
| BRF03: completion receipts | Released opt-in receipt enrichment for single, batch, wait and ticket-recovery status reads, advertised as `run_completion_version=1`. Batches share one wallet. Independent recovery remains available for absent/archived receipts. The helper calls the existing full challenge result route with its unchanged default, preserving compatibility with the deployed schema62 endpoint. |
| BRF04: restrained prefetch | Speculative comparison targets fall from six to two, retaining the two background slots and independent foreground selection. Six cold candidates now initiate four speculative HTTP requests rather than twelve. Local, account-scoped counters record speculative starts, subsequent use, queued cancellations and foreground starts; no new telemetry collection or UI was added. |
| BRF05: fresh standings reuse | Rivalry reads current members/appearances, bests, blocks, pending work and track/owner moderation data in batches. A complete fresh input fingerprint keys bounded process-local derived bytes. Matching revalidation skips standings preparation; time-dependent state, personal-best slots and current permission checks remain fresh. The existing Rivalry clock is shared across the new path. |

In the same synthetic SQLite account, Rivalry SELECTs fall **20→8**, and an unchanged304 also uses8 without rebuilding standings. Established wallet reads fall **6→2 total SQL statements**. Before/after decoded payloads match exactly. These are statement counts, not PostgreSQL latency or bill claims. [Measurements](evidence/backend-reuse-fixes-2026-10-26/read-measurements.json).

## Release and preservation

The API release is an eight-file overlay on the exact previously deployed ghost-cache image: `app.py`, `discovery_v3.py`, `preview_wire.py`, `economy.py`, `completion_reads.py`, `runs.py`, `rivalry.py` and `rivalry_reads.py`. It preserves274 existing package files,165 canonical-project files, the Linux engine and locked dependencies byte-for-byte. The two new capabilities were enabled only with their handlers. [Release proof](evidence/backend-reuse-fixes-2026-10-26/package-proof.json).

Managed Cloud SQL backup **1793041364432** succeeded before the zero-normal-traffic canary. Health/readiness, existing bootstrap fields, public-page hashes, preview reuse/fallback and unauthenticated completion denial passed before promotion and on the ordinary public URL. The temporary tag was removed. The previous ghost-cache revision remains available for rollback.

Schema remains `0062_retire_discovery_cache`. Worker, migration job, smoke job and private Studio specifications remain unchanged. Credentials, resource limits, networking, physics, storage packing and retention policies were preserved. This releases compatible read improvements; the wider working-tree schema69/features remain separate.

## Actual verification

- Exact Linux release image: **94passed,2skipped,60deselected**. The known additive-attempt downgrade guard is explicitly deselected; it reproduces on unchanged earlier images, and migrations are byte-identical in this release.
- Exact image with a new internal-network PostgreSQL17 fixture: **13passed,14deselected**. The precisely owned container/network and synthetic fixture credentials were removed.
- Working-source focused selection: **20passed**; retained Rivalry/appearance/awards/week/planning selection: **61passed**. The latter gate preceded the additional preview test, which is covered by the exact-image gate.
- Actual pinned Godot: **17** wallet/prefetch checks, **10** completion HTTP checks, **21** retained ghost HTTP checks, **122** download/cache checks and **25** retained comparison checks: **195 assertions passed**. Completion HTTP consumed actual single/batch/wait receipts with **zero reward or wallet follow-up requests**.
- New Python module/tests pass Ruff. Both the task-only source patch and exact deployed overlay pass Git reverse-apply checks.
- Final live health/capabilities and revision metadata passed; no provider ERROR-or-higher entry was observed at final verification. This is a point-in-time observation, not sustained operational acceptance.

Initial failures are retained in the [evidence report](evidence/backend-reuse-fixes-2026-10-26/report.json). Two new-test fixture assumptions were corrected without changing mechanism bounds. Seven retained week-boundary failures exposed the separate clock binding and were fixed before release; the original JUnit and final61-pass result remain. An evidence patch initially used Windows newline translation; byte-preserving patch generation corrected it without altering runtime behavior. Known native Windows root-certificate-store diagnostics remain in stderr; exact native process exits are0 and assertion summaries report no failures.

Actual commands and code-only operational copies are in the report. Main rollout entry point:

```text
.tools/backend-venv/Scripts/python.exe -X utf8 build/backend-reuse-fixes-2026-10-26/rollout.py <build|test|push|canary|promote>
.tools/backend-venv/Scripts/python.exe -X utf8 build/backend-reuse-fixes-2026-10-26/postgres_gate.py
.tools/backend-venv/Scripts/python.exe -X utf8 build/backend-reuse-fixes-2026-10-26/native_completion_gate.py
```

The [source checkpoint](evidence/backend-reuse-fixes-2026-10-26/scoped-source.patch) compares task-start sources rather than including concurrent working-tree changes. The [deployed overlay](evidence/backend-reuse-fixes-2026-10-26/deployed-overlay.patch) separately records the schema62 backport. No mixed-tree commit was created.

Owner/client reload and device acceptance remain. No physical-device attachment check/test, APK/export/install, real provider sign-in or purchase was performed. Cloud checks used public discovery queries and normal temporary discovery cursors plus unauthenticated status denial; no live player, score, purchase or reward record was created. Real player cache-hit rates, PostgreSQL performance under load and invoice savings remain unmeasured.
