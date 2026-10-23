# Achievement notifications — 22 October 2026

Granted achievements now appear in a native overlay during racing and menus. The existing original medal atlas, Barlow fonts and interface confirmation sound supply the presentation. Bronze, Silver, Gold, Platinum and Prestige retain their actual family and tier identities.

| Requirement | Implementation |
| --- | --- |
| AN01 | A 0.34-second arrival, one brief minted-edge glint, 4.2-second readable hold, 0.28-second exit and 0.18-second queue gap. Dark ink, restrained metal accents, achievement name and complete objective. |
| AN02 | Successfully committed local progress and authoritative account snapshots announce newly earned medals. Signed-in race/creator awards never use unverified client progress. Same-batch tier upgrades coalesce to the highest earned medal. |
| AN03 | One persistent overlay, input-transparent descendants, bounded 130-key deduplication and at most forty pending family entries. Account changes clear the current and queued awards. Loading, countdown, pause, publication prompts and application suspension retain the readable lifetime. |
| R01 / Q01 | Preserve the catalog, thresholds, trophies, profile choices, records, economy and canonical race behavior. Native views and original-regression checks accompany a source-only review patch. |

The race banner sits below the left instruments so the car and central road stay visible on short landscape screens. The results banner sits to the right below the tabs, keeping the main finish time, PB and bottom actions visible. Safe-area insets and viewport changes update placement. Text shaping gives rare longer honors their required line height; every family fits within a 160-unit maximum in the checked landscape layouts.

Local notifications start only after `LocalRecords.save_records()` commits. Failed saves and repeated saves produce no award. The achievement client observes exact unlocked keys, retaining the original separation of local care, guest racing and verified account progress. A first account collection without a saved baseline establishes history quietly. Cached/newly observed unlocks can then notify once per session. A cold first fetch can therefore suppress an award earned before that initial baseline arrives; this avoids inventing a historical/new distinction the API does not provide.

The app explicitly reads the sign-in baseline and refreshes the collection after persisted race verification receipts, accepted publications and newly observed finalized joined challenges or Rivalry finales. Receipt bursts share one delayed read, spaced by at least one second. Activity arriving during a request remains pending. Ordinary explicit/focus reads retain the existing one-minute throttle. Identity synchronization itself remains cache-only; collection browsing adds no periodic polling timer. Remote awards are observed when these existing client events or an explicit refresh occur; no push-notification service was added.

The overlay adds one canvas layer and one small control tree. It reuses the existing bounded medal texture cache. It creates no particles, shader, persistent image cache, 3D world or render target, and performs no runtime image readback. Only the native test captures read rendered pixels.

The focused fixture runs against disposable workspace profiles. It checks real app grants/results, saved-state rollback, account fencing, coalesced reads, historical suppression, exact tier copy, mouse/touch pass-through, countdown/pause/background lifetime, resize and rendered pixels, all 130 grant keys and every family objective at 960×540, 1280×720 and 1720×914. The original app/client sources reproduce two missing-notification failures. Initial attempts, fixture corrections, actual commands and final logs are retained in [the evidence report](evidence/achievement-overlay-2026-10-22/report.json).

Native previews:

- [Small landscape race](evidence/achievement-overlay-2026-10-22/compatibility/driving-bronze-960.png)
- [Medal entrance](evidence/achievement-overlay-2026-10-22/compatibility/driving-entrance.png)
- [Platinum](evidence/achievement-overlay-2026-10-22/compatibility/driving-platinum.png)
- [Prestige](evidence/achievement-overlay-2026-10-22/compatibility/driving-prestige.png)
- [Saved race achievement on results](evidence/achievement-overlay-2026-10-22/compatibility/results-earned.png)

The workspace already contained substantial unrelated changes. The review patch compares against the saved task baselines and explicitly excludes concurrent indexed track-discovery edits. Original backend queue, publication, reward and UI work is preserved.

Owner appearance, animation and physical-device acceptance remain. No phone attachment check or device test was performed. No APK, deployment, live account mutation, race submission, publication or reward grant was performed. Desktop screenshot/readback hitches are retained in logs and are not a runtime performance measurement.
