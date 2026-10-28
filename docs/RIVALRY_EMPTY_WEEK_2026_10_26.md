# Rivalry popup for an empty week, 2026-10-26

REW01: When the authoritative summary has no final rank and zero completed races, the banner hides the oversized missing-rank dash, diagonal rank divider, finish flag and small finish checkerboard. Muted **No races completed** copy explains the empty area. The existing week/player heading, outer checker strips, actual zero-valued statistics and both actions retain their positions.

REW02: Ranked weeks retain the approved reference composition and earned decorations. The condition uses the actual summary's `rank` and `completed` fields; it does not infer participation from points or invent a result. The small Final position card still shows the ordinary missing-value dash. Scoring, snapshots, membership, review markers, native miniature, dismissal and Continue behavior are unchanged by this task.

R01: Only the popup and its banner helper change at runtime. The existing real-App popup suite now explicitly checks that the missing-rank display is hidden only for an empty week, that the banner omits its finish ornament, and that the explanation appears within the hero bounds. All existing result data, ranked presentation, resize, keyboard, modal, stale-account, dismissal, failure/retry and rollover assertions remain. The new message uses the existing translation lookup with English fallback; translated copy and owner appearance/touch acceptance remain.

Q01: Actual native results, commands, source/screenshot hashes and a task-only review patch are recorded in [report.json](evidence/rivalry-empty-week-2026-10-26/report.json). Tests use unique disposable saves under `build/rivalry-empty-week/userdata`, disable `BMT_API_URL` and use the existing local delayed Rivalry service fixture. The fixture covers six achievement states at four sizes, live resizing and multiple locales in both desktop renderers.

[Empty-week popup](evidence/rivalry-empty-week-2026-10-26/ui/unranked-1280x720.png) and [retained champion appearance](evidence/rivalry-empty-week-2026-10-26/ui/champion-1280x720.png) are native Compatibility captures. Desktop Mobile counterparts are under `ui/mobile`.

Reload and owner/device appearance, touch and translation acceptance remain. No physical-device test or attachment check, APK/build/install, real authentication/purchase, owner-save or live database mutation, deployment or owner-process restart was performed. No staging or commit; concurrent work is preserved.
