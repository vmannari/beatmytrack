# Read-only cloud cost review evidence

See [measured headroom, saving calculations, tradeoffs, commands and next acceptance](../../CLOUD_COST_REVIEW_2026_10_06.md).

- inventory.json: actual compiler-22 API/worker limits/scaling, SQL storage/backups and registry digest inventory; no secret values.
- metric-summary.json: preceding-day sampled means/maxima and pagination/error status.
- sql/api/worker metric JSON: Cloud Monitoring observations underlying the summary. CPU/memory distribution means are samples, not guaranteed maximum input usage.
- saving-calculations.json: reviewed regional EUR small-SQL and memory savings estimates; conditional candidates only.
- before-* files, scoped-change.patch and source-hashes.json: review-only checkpoint, preserving prior/shared dirty work.

No cloud configuration, data, image, secret, scheduler or runtime behavior was changed. No benchmarked downsizing or proven no-impact savings are claimed. Raw registry digests can include required manifest children; deletion requires a dry-run keep policy for deployed, rollback and historical verifier artifacts.
