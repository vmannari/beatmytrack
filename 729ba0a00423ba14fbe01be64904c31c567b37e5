# Track of the Day results: approved draft implemented

DRD01: The result screen follows the selected draft using native Godot controls: brand/track/car header, achievement and large best flying lap, enlarged earned medal, nine stage segments, compact flying-lap cards, adjacent standings and a fixed action footer. Portrait stacks the panels inside a scroll area; retry/back remain visible. Bronze/silver/gold/Elite milestone positions are exactly stages 1/4/6/9. Failed laps remain red, the best flying lap receives a yellow outline, and the opening lap is excluded.

DRD02: Inline standings query the existing read-only flying-lap endpoint for the completed attempt's UTC day, revision, car and lap ticks. The service currently supplies the nearest driver on each side, so the panel shows those actual neighbours and the highlighted attempt rather than the draft's five illustrative rows. The self row retains exact milliseconds. Its position is a comparison of this attempt with the compatible best-lap population, not a claim that a daily elimination result was uploaded or verified. The full leaderboard retains its existing independent browsing/pagination.

DRD03: Loading, errors with retry, absent service context, guest reads, account changes, stale replies, post-verification refresh and UTC expiration are handled explicitly. Previous rows/rank clear immediately before a read. Replies must match day/revision/car/end/tick rate and candidate lap, with bounded integer timing/ranking fields. No fabricated fallback standings appear.

DRD04: Existing brand SVG, Barlow fonts, native medals/laurels and authored biome artwork supply production assets. The generated draft remains a design reference. The backdrop follows the completed track's biome; the game's race camera and simulation are unchanged. Seven new messages have direct authored copy in all twelve languages; portrait uses the existing short Back action to avoid Japanese/Italian overflow.

Runtime files changed: `game/ui/daily_elimination_results.gd`, new `game/ui/daily_results_standings.gd` and its UID, and one additional biome assignment in `game/core/app.gd`. Supporting changes are the new design regression, two retained fixture adaptations, seven authored catalogue entries, and task-owned evidence tooling. The presentation fixture now checks each card's actual lap number/time rather than the superseded two-column table structure; its no-limit/no-percentage assertions remain.

## Validation

Commands run from the repository root:

```powershell
python docs/evidence/daily-results-design-2026-11-02/catalogues.py
python docs/evidence/daily-results-design-2026-11-02/run_native.py --import-catalogues
python docs/evidence/daily-results-design-2026-11-02/run_native.py
python docs/evidence/daily-results-design-2026-11-02/run_native.py --graphical
python docs/evidence/daily-results-design-2026-11-02/run_native.py --graphical --mobile
python docs/evidence/daily-results-design-2026-11-02/run_native.py test_daily_elimination
python docs/evidence/daily-results-design-2026-11-02/run_native.py test_daily_elimination_app
python docs/evidence/daily-results-design-2026-11-02/run_native.py test_daily_fixed_presentation
python docs/evidence/daily-results-design-2026-11-02/run_native.py test_daily_standings
python docs/evidence/daily-results-design-2026-11-02/checkpoint.py
```

Final design regression: **173 checks, 0 failures on each desktop renderer**, including eleven captures per renderer. The native layouts cover 1280×720, 1920×1080, 960×540, 844×390 and 390×844, plus elimination/medal/error/expiry cases. All twelve languages fit at portrait, compact landscape and desktop widths. The regression exercises the completed-attempt query, exact self milliseconds, milestone positions, retry/return signals, full-board opening, failed read/recovery, wrong candidate and scope rejection, pending account changes, guest comparison, own-PB deduplication, midnight clearing and owned-read cancellation.

Retained rules/results **115/0**, actual App flow **17/0**, fixed presentation **438/0**, existing full standings **38/0**, and **84** scoped authored-language/placeholder checks pass. The import exits successfully, with the existing certificate-store warning and missing Android build-tools directory message; it is not an Android build. Native test logs also retain the certificate-store warning.

Initial results are retained in the evidence folder: one portrait grid overflow, then two translated action overflows. The grid now computes columns from available viewport width instead of its previous minimum; the narrow Back label fixes the translated footer. No timing, medal or scope assertion was relaxed. Patch-generation attempts that rejected before changing any file were corrected by writing the owned result source while retaining its UTF-8 BOM.

## Review and limits

- [1280×720 native result](evidence/daily-results-design-2026-11-02/elite-1280x720.png)
- [1920×1080 native result](evidence/daily-results-design-2026-11-02/elite-1920x1080.png)
- [Portrait](evidence/daily-results-design-2026-11-02/elite-390x844.png)
- [Desktop Mobile renderer](evidence/daily-results-design-2026-11-02/mobile/elite-1280x720.png)
- [All logs, captures and scoped checkpoint](evidence/daily-results-design-2026-11-02/)

Automated commands use pinned Godot 4.7.2, isolated APPDATA/LOCALAPPDATA, an empty service origin and process-scoped crash-dialog suppression. Captures use explicit synthetic responses through actual runtime UI, not a live account. No physical phone/device test was performed. Reload and owner visual/touch acceptance remain. No backend change, live mutation/deployment, APK, owner-save/process restart, or main-index staging/commit/merge was performed. Concurrent changes are preserved; the checkpoint is relative to task-start files rather than repository HEAD.
