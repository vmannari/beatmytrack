# Further backend reuse opportunities — 26 October 2026

**The best next change is reusable track previews, followed by cheaper wallet refreshes and bundling post-race receipts into responses the client already reads.** These extend the same approach as ghost caching: reuse stable content and transfer current state separately.

This is a review and bounded local measurement. No application source, cloud configuration, player records, retention policy or deployment was changed. Requirements BRO01 distinguish deployed/source capabilities; BRO02 measure representative mechanisms; BRO03 prioritise changes and preserve authority; BRO04 retain reproducible evidence.

The public bootstrap was read at **2026-10-26T17:25:24 UTC**. Ghost identity/compact transport and batched run status are advertised. Preview reuse, completion receipts and compact race paths are not advertised. The inspected deployed code is the exact frozen package from the preceding [ghost-cache deployment](BACKEND_GHOST_CACHE_DEPLOYMENT_2026_10_26.md). Local source contains additional features; they require compatible release work, not merely adding bootstrap flags.

## Recommended order

| Priority | Opportunity | What is established | Proposed work |
|---|---|---|---|
| 1 | Reuse track-card outlines | Local client/server already support exact preview hashes and omission of retained geometry; live bootstrap does not advertise it. | Release compatible preview support as a focused update. Continue returning current ratings, identity and availability; restore cached outlines by hash, with full-response fallback for missing/corrupt entries. |
| 2 | Reduce wallet refresh work | Every successful Garage visibility activation can call `economy.refresh()`. It has in-flight protection but no freshness interval. The deployed route repeats the locked wallet/provenance path. | Release the existing coherent established-wallet read; add a short client freshness window with explicit invalidation after rewards, purchases and account changes. Preserve locked recovery for missing wallets and server validation at checkout. |
| 3 | Include reward/wallet receipts in completion responses | Current client consumes optional completion receipts; local `completion_reads.py` supplies them. Live bootstrap lacks this capability. Otherwise a credited result can require a reward GET followed by a wallet GET. | Roll out compatible enrichment on single/batch status reads. Return the wallet once per account batch, retain independent recovery for absent/archived receipts, and retain current challenge permissions. This can remove up to two follow-up reads for the ordinary credited-result path. |
| 4 | Reduce unused comparison prefetch | Sign-in/menu warming can queue six distinct tracks, with one comparison and one leaderboard request per uncached target. Parallelism and ten-minute snapshots are already bounded. | Measure how many prefetched results are actually used. Consider selected track plus fewer neighbours or delayed warming, particularly on constrained connections. Six cold targets can cause up to twelve requests; reducing them trades some browse readiness for lower work. |
| 5 | Avoid rebuilding unchanged competition snapshots | The existing Rivalry ETag avoids response bytes after the complete snapshot is computed. | Consider a cheap, complete revision check or reusable structural snapshot. Retain current membership, visibility, block/deletion, standings and week-boundary checks. A tag must cover every relevant change; a full-response cache keyed only by group ID would be insufficient. |
| 6 | Separate stable prices/rarity/previews from account updates | The wallet includes all 87 prices on each read. News already deduplicates outlines within a page but repeats them across responses; achievements already have disk snapshots and refresh throttling. | Version reusable catalogue/rarity/media data where measurements justify it. Keep account progress, wallet/ownership and current access separate. This is a smaller next step than preview reuse and avoiding entire requests. |

## Actual local measurements

The [probe](evidence/backend-reuse-review-2026-10-26/code/probe.py) uses actual outlines from twenty bundled official track documents with synthetic card metadata. It executes the existing `compact_previews` helper. With gzip level3 and the existing 1,024-byte compression threshold, the repeat-page payload model changes from **35,325 bytes to 2,975 bytes**, including request hints and response bodies: **91.58% less for this fully warm fixture**. Response-only bytes change from35,279 to2,113. The initial compact response is slightly larger,36,369 bytes, because hashes accompany the uncached outlines. Headers/TLS are excluded; real cards, hit rates, cold installs and navigation mix will change the result. This is not a bill-saving percentage. Updated rating counts remain present and cached geometry reconstructs exactly. [Complete payload figures](evidence/backend-reuse-review-2026-10-26/preview-payload.json).

A new synthetic SQLite account exercises the deployed package through real FastAPI HTTP handlers. Repeating the unchanged wallet returns200, the same2,348 decoded bytes /672 compressed response bytes and six SQL statements; no ETag is supplied. The current source's `established_wallet` function, placed behind a temporary local comparison route with the same authentication fixture and middleware, returns the identical wallet using **two SELECT statements**, including the fixture's common authentication read. The deployed path includes a SQLite-specific update lock; this count is not a PostgreSQL timing or lock claim. The comparison route was never deployed. [Wallet comparison](evidence/backend-reuse-review-2026-10-26/source-fast-wallet.json).

The same synthetic account, enrolled against six invented Rivalry tracks, returns304 with no response body on unchanged revalidation, while still executing **20 SELECT statements**, the same count as its full response. This demonstrates the difference between saving transfer and saving database work. The account is small, authentication is a test override, and SQLite statement counts do not establish production capacity. Minimal news/achievement fixtures also return their unchanged full bodies; their existing client freshness controls already limit demand. [API observations](evidence/backend-reuse-review-2026-10-26/synthetic-api-reads.json).

## Reuse already present

- Full track documents are cached and validated by exact content hash. The current installed bundle contains **26 documents /205,019 raw bytes**; keep it aligned with common published hashes rather than building a second track cache.
- Concurrent identical GET requests are coalesced, and the client retains bounded ETag responses. This merges overlapping reads, not successive menu visits after a read completes.
- Rankings have a sixty-second client freshness window; achievements have persisted snapshots, activity coalescing and normal refresh throttling; News has normal sixty-second freshness checks.
- Run status batching and wait support are advertised. Comparison snapshots already persist for ten minutes. Gzip and compact ghost downloads are active mechanisms.
- Most visual assets are installed with the game. Additional backend image caching should follow evidence of a network fetch, not assume these assets are downloaded repeatedly.

Compact race-path upload transport also exists locally and is not advertised live. It is a separate upload/decoder compatibility rollout whose compressed-byte benefit needs measurement; it does not directly eliminate the download bill. Skipping competitive verification or changing recording retention is outside this reuse recommendation.

Private caches and server validators must respect access changes. HTTP explicitly distinguishes private/shared caches and defines revalidation; see [RFC9111 sections3.5 and4.3](https://www.rfc-editor.org/rfc/rfc9111.html#section-3.5). A304 still represents a request reaching the server. Database savings require avoiding the expensive preparation as well.

## Evidence and acceptance

Actual commands:

```text
.tools/backend-venv/Scripts/python.exe -X utf8 build/backend-reuse-review-2026-10-26/probe.py
.tools/backend-venv/Scripts/python.exe -X utf8 build/backend-reuse-review-2026-10-26/wallet_probe.py
```

The first default-sandbox attempt could not open the public HTTPS connection; the approved scoped rerun succeeded. Both final probes passed their payload-equivalence, current-field, exact-reconstruction and SQL-count assertions. The only remote request was unauthenticated `GET /v1/bootstrap`. All account/track writes were inside new synthetic local SQLite fixtures. Code copies and hashes are retained in the [evidence report](evidence/backend-reuse-review-2026-10-26/report.json); original entry points use the build paths above. Existing services/game processes were not restarted. No physical-device attachment check/test, APK, real sign-in/purchase, live migration or deployment was performed. Measured player journeys, PostgreSQL load and invoices remain acceptance for any selected implementation.
